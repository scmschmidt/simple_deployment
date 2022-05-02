
# Here some important locals to make it easier to change certain things.
locals {
  # URI to libvirt.
  libvirt_uri = var.location
  machine_ids = toset(keys(var.machines))
  used_os = toset([for key, val in var.machines: val[1]])
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
    # Pinned dmacvicar/libvirt to version 0.6.10 because later version have a bug which can prevent SSH-based libvirt connections: https://github.com/dmacvicar/terraform-provider-libvirt/issues/864
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "= 0.6.10"
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

# The master images for all used operating systems.
resource "libvirt_volume" "master" {
  for_each = local.used_os
  name   = "${var.name}-master-${each.key}.qcow2"
  source = local.image_map[each.key]
  format = "qcow2"
}

# Each virtual machine needs its own disk pointing to a master.
resource "libvirt_volume" "volume" {
  for_each       = local.machine_ids
  name           = "${var.name}-${var.machines[each.key][1]}-${each.key}.qcow2"
  base_volume_id = libvirt_volume.master[var.machines[each.key][1]].id
  size           = lookup(local.sizing_map[var.machines[each.key][0]], "disksize") != 0 ? lookup(local.sizing_map[var.machines[each.key][0]], "disksize") * 1024 * 1024 : null
}

# Use cloudinit to do some preparation.
resource "libvirt_cloudinit_disk" "cloudinit_disk" {
  name = "${var.name}_cloudinit.iso"
  user_data      = local.cloudinit_userdata
  network_config = templatefile("${path.module}/cloudinit.network.tftpl", {})
}

# Create the machine.
resource "libvirt_domain" "domain" {
  for_each  = local.machine_ids
  name      = "${var.name}-${each.key}"
  memory    = lookup(local.sizing_map[var.machines[each.key][0]], "memory")
  vcpu      = lookup(local.sizing_map[var.machines[each.key][0]], "vcpu")
  cloudinit = libvirt_cloudinit_disk.cloudinit_disk.id
  network_interface {
    network_name   = var.name
    wait_for_lease = true # This makes sure, an apply returns if the IP address has been set!
  }
  disk {
    #volume_id = element(libvirt_volume.volume.*.id, count.index)
    volume_id = libvirt_volume.volume[each.key].id
  }
}