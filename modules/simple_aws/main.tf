# Here some important locals to make it easier to change certain things.
locals {
  # If the deprecated 'admin_user_key' is used, we create 'admin_user_keys' with one entry 
  # otherwise we use the new 'admin_user_keys' directly with files resolved.
  admin_user_keys_resolved = [ for e in local.admin_user_keys : startswith(e, "@") ? file(substr(e, 1, -1)) : e]
  admin_user_keys = var.admin_user_key != null ? [var.admin_user_key] : var.admin_user_keys

  # If the deprecated 'admin_user_key' is used, we create 'admin_user_keys' with one entry 
  # otherwise we use the new 'admin_user_keys' directly
  subscription_registration_keys = var.subscription_registration_key != "-" ? [var.subscription_registration_key] : var.subscription_registration_keys

  # New machine definition format has four entries (size, image, ssh key slot, reg key slot),
  # but the old two entry-format (size, image) needs to be supported, so as default the 
  # first slots (0, 0) are always used.
  machine_definitions = {for k, v in var.machines : k => [
      v[0], v[1],
      length(v) > 2 ? local.admin_user_keys[v[2]] : local.admin_user_keys[0],
      length(v) > 2 ? local.subscription_registration_keys[v[3]] : local.subscription_registration_keys[0]]}

  # Create bastion definition with resolved SSH and registration keys.
  bastion_definition = length(var.bastion) == 0 ? [] : [var.bastion[0], 
                                                        var.bastion[1], 
                                                        local.admin_user_keys[var.bastion[2]], 
                                                        local.subscription_registration_keys[var.bastion[3]]]

  # Set with machine IDs for iteration.
  machine_ids = toset(keys(var.machines))

  # Get image and size map from definition files.
  image_map  = yamldecode(file("${path.root}/images_aws.yaml"))[var.location]
  sizing_map = yamldecode(file("${path.root}/sizing_aws.yaml"))

  # Load cloud-init template.
  cloudinit_template = fileexists("${path.root}/cloudinit.user-data.tftpl") ? "${path.root}/cloudinit.user-data.tftpl" : "${path.module}/cloudinit.user-data.tftpl"

}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.75"
    }
  }
  required_version = ">= 1.1.0"
}

provider "aws" {
  profile = "default"
  region  = var.location
  default_tags {
   tags = {
    owner = var.owner_tag
    managed_by = var.managed_by_tag
    application = var.application_tag
   }
  }
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

  # Incoming ICMP
  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
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
  ami           = local.image_map[local.machine_definitions[each.key][1]]
  instance_type = local.sizing_map[local.machine_definitions[each.key][0]]
  vpc_security_group_ids      = [aws_security_group.security_group.id]
  associate_public_ip_address = true
  subnet_id                   = module.vpc.public_subnets[0]
  user_data_base64            = base64encode(templatefile(local.cloudinit_template, { 
    keymap = var.keymap,
    admin_username = var.admin_user, 
    admin_user_key = local.machine_definitions[each.key][2], 
    subscription_registration_key = local.machine_definitions[each.key][3],
    registration_server = var.registration_server,
    enable_root_login = var.enable_root_login ? 1 : 0
  }))
  tags = {
    Name = "${var.name}-${each.key}"
  }

  # Shutdowned machines shall not lead to a redeployment on apply.
  lifecycle {
    ignore_changes = [associate_public_ip_address]
  }
}
