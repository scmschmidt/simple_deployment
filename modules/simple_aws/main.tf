# Here some important locals to make it easier to change certain things.
locals {
  machine_ids = toset(keys(var.machines))
  image_map  = yamldecode(file("${path.root}/images_aws.yaml"))[var.location]
  sizing_map = yamldecode(file("${path.root}/sizing_aws.yaml"))
  cloudinit_template = fileexists("${path.root}/cloudinit.user-data.tftpl") ? "${path.root}/cloudinit.user-data.tftpl" : "${path.module}/cloudinit.user-data.tftpl"
  cloudinit_userdata = templatefile(local.cloudinit_template, { keymap = var.keymap,
                                                                admin_username = var.admin_user, 
                                                                admin_user_key = var.admin_user_key, 
                                                                subscription_registration_key = var.subscription_registration_key,
                                                                registration_server = var.registration_server,
                                                                enable_root_login = var.enable_root_login ? 1 : 0
                                                              })
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.75"
    }
  }
  required_version = ">= 1.1.0"
}

provider "aws" {
  profile = "default"
  region  = var.location
}

# For the VPC we need the available availability zones.
data "aws_availability_zones" "available" {
  state = "available"
}

# Create VPC.
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name = "${var.name}-vpc"
  cidr = var.subnet
  azs             = data.aws_availability_zones.available.names
  private_subnets = []
  public_subnets  = [var.subnet]
  enable_nat_gateway = false
  single_nat_gateway = true
  tags = {
    Name = "${var.name}-vpc"
  }
}

# Crete security group to allow traffic.
resource "aws_security_group" "security_group" {
  name   = "${var.name}-security_group"
  vpc_id = module.vpc.vpc_id

  # Incoming SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outgoing traffic
  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-security_group"
  }
}

# Create the instance.
resource "aws_instance" "instance" {
  for_each      = local.machine_ids
  ami           = local.image_map[var.machines[each.key][1]]
  instance_type = local.sizing_map[var.machines[each.key][0]]
  vpc_security_group_ids      = [aws_security_group.security_group.id]
  associate_public_ip_address = true
  subnet_id                   = module.vpc.public_subnets[0]
  user_data                   = local.cloudinit_userdata
  
  tags = {
    Name = "${var.name}-${each.key}"
  }

  # Shutdowned machines shall not lead to a redeployment on apply.
  lifecycle {
    ignore_changes = [associate_public_ip_address]
  }
}
