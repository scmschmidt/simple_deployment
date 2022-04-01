
# Here some important locals to make it easier to change certain things.
locals {
  # URI to libvirt.
  libvirt_uri = var.location
  image_map   = yamldecode(file("${path.root}/images_libvirt.yaml"))
  sizing_map  = yamldecode(file("${path.root}/sizing_libvirt.yaml"))
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
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.6.14"
    }
  }
  required_version = ">= 1.1.0"
}

# Configure the Libvirt provider.
provider "libvirt" {
  uri = local.libvirt_uri
}

# We creaete our own network for all machines with dhcp and NAT. 
resource "libvirt_network" "network" {
  name      = var.name
  mode      = "nat"
  autostart = true
  addresses = [var.subnet]
  dns {
    forwarders {
      address = cidrhost(var.subnet, 1) # First IP is always the DNS server and default gateway.
      domain  = var.name
    }
  }
  dhcp {
    enabled = true
  }
}

# The master image for all virtual machines.
resource "libvirt_volume" "master" {
  name   = "${var.name}-${var.image}.qcow2"
  source = local.image_map[var.image]
  format = "qcow2"
}

# Each virtual machine needs its own disk.
resource "libvirt_volume" "volume" {
  name           = "${var.name}-${var.image}-${count.index}.qcow2"
  base_volume_id = libvirt_volume.master.id
  count          = var.amount
  #size           = var.disk_size != 0 ? var.disk_size * 1024 * 1024 : null
  size = lookup(local.sizing_map[var.size], "disksize") != 0 ? lookup(local.sizing_map[var.size], "disksize") * 1024 * 1024 : null
}

# Use cloudinit to do some preparation.
resource "libvirt_cloudinit_disk" "cloudinit_disk" {
  name = "${var.name}_cloudinit.iso"
  #user_data      = data.template_file.user_data.rendered
  #network_config = data.template_file.network_config.rendered
  user_data      = local.cloudinit_userdata
  network_config = templatefile("${path.module}/cloudinit.network.tftpl", {})
}

# Create the machine.
resource "libvirt_domain" "domain" {
  count = var.amount
  name  = "${var.name}-${var.image}-${count.index}"
  #memory    = var.memory
  #vcpu      = var.vcpu
  memory    = lookup(local.sizing_map[var.size], "memory")
  vcpu      = lookup(local.sizing_map[var.size], "vcpu")
  cloudinit = libvirt_cloudinit_disk.cloudinit_disk.id
  network_interface {
    network_name   = var.name
    wait_for_lease = true # This makes sure, an apply returns if the IP address has been set!
  }
  disk {
    volume_id = element(libvirt_volume.volume.*.id, count.index)
  }
}