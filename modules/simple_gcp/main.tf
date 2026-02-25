# Here some important locals to make it easier to change certain things.
locals {

  # Derive region and zone from location.
  parts = split("-", var.location)
  region = join("-", slice(local.parts, 0, length(local.parts)-1))
  zone = var.location

  # If the deprecated 'admin_user_key' is used, we create 'admin_user_keys' with one entry 
  # otherwise we use the new 'admin_user_keys' directly with files resolved.
  admin_user_keys_resolved = [ for e in var.admin_user_keys : startswith(e, "@") ? file(substr(e, 1, -1)) : e]
  admin_user_keys = var.admin_user_key != null ? [var.admin_user_key] : local.admin_user_keys_resolved

  # If the deprecated 'admin_user_key' is used, we create 'admin_user_keys' with one entry 
  # otherwise we use the new 'admin_user_keys' directly
  subscription_registration_keys = var.subscription_registration_key != "-" ? [var.subscription_registration_key] : var.subscription_registration_keys

  # Divide subnet into a private part (for machines) and a public part for the NAT gateway.
  subnets = cidrsubnets(var.subnet, 1, 1)

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
  image_map  = yamldecode(file("${path.root}/images_gcp.yaml"))
  sizing_map = yamldecode(file("${path.root}/sizing_gcp.yaml"))

  # Load startup-scripts
  startup_script_template = fileexists("${path.root}/setup.tftpl") ? "${path.root}/setup.tftpl" : "${path.module}/setup.tftpl"
  
  # Load cloud-init template.
  # cloudinit_template = fileexists("${path.root}/cloudinit.user-data.tftpl") ? "${path.root}/cloudinit.user-data.tftpl" : "${path.module}/cloudinit.user-data.tftpl"
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.20"
    }
  }
  required_version = ">= 1.5.0"
}

provider "google" {
  project = var.project
  region  = local.region
  zone    = local.zone
  default_labels = {
    owner       = replace(var.owner_tag, "/[^a-z0-9_-]/", "_")
    application = replace(var.managed_by_tag, "/[^a-z0-9_-]/", "_")
    managed_by  = replace(var.application_tag, "/[^a-z0-9_-]/", "_")
  }
}

# Create VPC.
resource "google_compute_network" "vpc_network" {
  name                    = "${var.name}-network"
  auto_create_subnetworks = false
}

# Create private subnet.
resource "google_compute_subnetwork" "private_subnet" {
  name          = "${var.name}-private-subnet"
  ip_cidr_range = var.subnet
  network       = google_compute_network.vpc_network.id
}

# Create firewall rules.
resource "google_compute_firewall" "firewall" {
  name    = "${var.name}-firewall"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${var.name}-access"]
}

# Deploy the virtual machines.
resource "google_compute_instance" "linux_vm" {
  for_each      = local.machine_ids
  name          = "${var.name}-${each.key}"
  machine_type  = local.sizing_map[local.machine_definitions[each.key][0]]
  tags          = google_compute_firewall.firewall.target_tags

  boot_disk {
    initialize_params {
      image = local.image_map[local.machine_definitions[each.key][1]]
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.id

    # Including the access_config block assigns a Public IP.
    dynamic "access_config" {
      for_each = length(var.bastion) == 0 ? [1] : []
      content {}
    }
  }
  metadata_startup_script = templatefile(local.startup_script_template, {keymap                        = var.keymap,
                                                                         admin_username                = var.admin_user, 
                                                                         admin_user_key                = local.machine_definitions[each.key][2], 
                                                                         subscription_registration_key = local.machine_definitions[each.key][3],
                                                                         registration_server           = var.registration_server,
                                                                         enable_root_login             = var.enable_root_login ? 1 : 0
                                                                        })
  metadata = { 
    # user-data               = templatefile(local.cloudinit_template, {keymap                        = var.keymap,
    #                                                                   admin_username                = var.admin_user, 
    #                                                                   admin_user_key                = local.machine_definitions[each.key][2], 
    #                                                                   subscription_registration_key = var.subscription_registration_key,
    #                                                                   subscription_registration_key = local.machine_definitions[each.key][3],
    #                                                                   registration_server           = var.registration_server,
    #                                                                   enable_root_login             = var.enable_root_login ? 1 : 0
    #                                                                  })
    enable-oslogin         = false  # Do not use GCP Project OS Login approach for SSH Keys
    block-project-ssh-keys = true   # Do not use GCP Project Metadata approach for SSH Keys
  }
}

# Create NAT gateway.
resource "google_compute_router" "router" {
  count   = length(var.bastion) == 0 ? 0 : 1
  name    = "${var.name}-nat-router"
  network = google_compute_network.vpc_network.id
}
resource "google_compute_router_nat" "nat" {
  name                               = "${var.name}-nat-gateway"
  count                              = length(var.bastion) == 0 ? 0 : 1
  router                             = google_compute_router.router[0].name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Bastion virtual machine.
resource "google_compute_instance" "bastion" {
  count        = length(var.bastion) == 0 ? 0 : 1
  name         = "${var.name}-bastion"
  machine_type = local.sizing_map[var.bastion[0]]
  tags          = google_compute_firewall.firewall.target_tags

  boot_disk {
    initialize_params {
      image = local.image_map[var.bastion[1]]
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.id

    # Including the access_config block assigns a Public IP.
    access_config {}
  }
  metadata_startup_script = templatefile(local.startup_script_template, {keymap                        = var.keymap,
                                                                         admin_username                = var.admin_user, 
                                                                         admin_user_key                = local.bastion_definition[2],
                                                                         subscription_registration_key = local.bastion_definition[3],
                                                                         registration_server           = var.registration_server,
                                                                         enable_root_login             = var.enable_root_login ? 1 : 0
                                                                        })
  metadata = { 
    # user-data               = templatefile(local.cloudinit_template, {keymap                        = var.keymap,
    #                                                                   admin_username                = var.admin_user, 
    #                                                                   admin_user_key                = local.bastion_definition[2],
    #                                                                   subscription_registration_key = local.bastion_definition[3],
    #                                                                   subscription_registration_key = local.machine_definitions[each.key][3],
    #                                                                   registration_server           = var.registration_server,
    #                                                                   enable_root_login             = var.enable_root_login ? 1 : 0
    #                                                                  })
    enable-oslogin         = false  # Do not use GCP Project OS Login approach for SSH Keys
    block-project-ssh-keys = true   # Do not use GCP Project Metadata approach for SSH Keys
  }
}