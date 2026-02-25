# Here some important locals to make it easier to change certain things.
locals {

  # Derive region and zone from location.
  parts = split("-", var.location)
  region = join("-", slice(local.parts, 0, length(local.parts)-1))
  zone = var.location

  machine_ids = toset(keys(var.machines))
  image_map  = yamldecode(file("${path.root}/images_gcp.yaml"))
  sizing_map = yamldecode(file("${path.root}/sizing_gcp.yaml"))

  startup_script_template = fileexists("${path.root}/setup.tftpl") ? "${path.root}/setup.tftpl" : "${path.module}/setup.tftpl"
  startup_script = templatefile(local.startup_script_template, { keymap = var.keymap,
                                                                 admin_username = var.admin_user, 
                                                                 admin_user_key = var.admin_user_key, 
                                                                 subscription_registration_key = var.subscription_registration_key,
                                                                 registration_server = var.registration_server,
                                                                 enable_root_login = var.enable_root_login ? 1 : 0
                                                               })
  # cloudinit_template = fileexists("${path.root}/cloudinit.user-data.tftpl") ? "${path.root}/cloudinit.user-data.tftpl" : "${path.module}/cloudinit.user-data.tftpl"
  # cloudinit_userdata = templatefile(local.cloudinit_template, { keymap = var.keymap,
  #                                                               admin_username = var.admin_user, 
  #                                                               admin_user_key = var.admin_user_key, 
  #                                                               subscription_registration_key = var.subscription_registration_key,
  #                                                               registration_server = var.registration_server,
  #                                                               enable_root_login = var.enable_root_login ? 1 : 0
  #                                                             })
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
  auto_create_subnetworks = true
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
  machine_type  = local.sizing_map[var.machines[each.key][0]]
  tags          = google_compute_firewall.firewall.target_tags

  boot_disk {
    initialize_params {
      image = local.image_map[var.machines[each.key][1]]
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name

    # Including the access_config block assigns a Public IP
    access_config {
      // Ephemeral public IP
    }
  }
  metadata_startup_script = local.startup_script
  metadata = { 
    #user-data              = local.cloudinit_userdata
    enable-oslogin         = false  # Do not use GCP Project OS Login approach for SSH Keys
    block-project-ssh-keys = true   # Do not use GCP Project Metadata approach for SSH Keys
  }
}

