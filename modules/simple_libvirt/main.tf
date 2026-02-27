
# Here some important locals to make it easier to change certain things.
locals {
  # URI to libvirt.
  libvirt_uri = var.location

  # Collect used OS releases.
  used_os = toset([for key, val in var.machines: val[1]])

  # If the deprecated 'admin_user_key' is used, we create 'admin_user_keys' with one entry 
  # otherwise we use the new 'admin_user_keys' directly with files resolved.
  admin_user_keys_resolved = [ for e in var.admin_user_keys : startswith(e, "@") ? file(substr(e, 1, -1)) : e]
  admin_user_keys = var.admin_user_key != null ? [var.admin_user_key] : local.admin_user_keys_resolved

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

  # Set with machine IDs for iteration.
  machine_ids = toset(keys(var.machines))

  # Get image and size map from definition files.
  image_map   = yamldecode(file("${path.root}/images_libvirt.yaml"))
  sizing_map  = yamldecode(file("${path.root}/sizing_libvirt.yaml"))

  # Load cloud-init template.
  cloudinit_template = fileexists("${path.root}/cloudinit.user-data.tftpl") ? "${path.root}/cloudinit.user-data.tftpl" : "${path.module}/cloudinit.user-data.tftpl"
}


terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.8.3"   # latest working version (rewrite with 0.9.0!)
    }
  }
  required_version = ">= 1.1.0"
}

# Configure the libvirt provider.
provider "libvirt" {
  uri = local.libvirt_uri
}

# We create our own network for all machines with dhcp and NAT (if no bridge is defined). 
resource "libvirt_network" "network" {
  count     = var.network_bridge != "" ? 0 : 1
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
  name           = "${var.name}-${local.machine_definitions[each.key][1]}-${each.key}.qcow2"
  base_volume_id = libvirt_volume.master[local.machine_definitions[each.key][1]].id
  size           = lookup(local.sizing_map[local.machine_definitions[each.key][0]], "disksize") != 0 ? lookup(local.sizing_map[local.machine_definitions[each.key][0]], "disksize") * 1024 * 1024 : null
}

# Use cloudinit to do some preparation.
resource "libvirt_cloudinit_disk" "cloudinit_disk" {
  for_each       = local.machine_ids
  name           = "${var.name}-${each.key}_cloudinit.iso"
  user_data      = templatefile(local.cloudinit_template, {keymap = var.keymap,
                                                           admin_username = var.admin_user, 
                                                           admin_user_key = local.machine_definitions[each.key][2], 
                                                           subscription_registration_key = local.machine_definitions[each.key][3],
                                                           registration_server = var.registration_server,
                                                           enable_root_login = var.enable_root_login ? 1 : 0
                                                          })
  network_config = templatefile("${path.module}/cloudinit.network.tftpl", {})
}

# Create the machines.
resource "libvirt_domain" "domain" {
  
  for_each  = local.machine_ids
  name      = "${var.name}-${each.key}"
  memory    = lookup(local.sizing_map[local.machine_definitions[each.key][0]], "memory")
  vcpu      = lookup(local.sizing_map[local.machine_definitions[each.key][0]], "vcpu")
  cloudinit = libvirt_cloudinit_disk.cloudinit_disk[each.key].id
  qemu_agent = var.network_bridge != "" ? true : false

  # Interface in new network (if bridge was not set).
  dynamic "network_interface" {
    for_each = var.network_bridge == "" ? [1] : []

    content {
      network_name   = var.name
      wait_for_lease = true # This makes sure, an apply returns if the IP address has been set!
    }
  }

  # Network bridge (if bridge was set).
  dynamic "network_interface" {
    for_each = var.network_bridge != "" ? [1] : []

    content {
      bridge = var.network_bridge 
      wait_for_lease = true # This makes sure, an apply returns if the IP address has been set!
    }
  }

  disk {
    #volume_id = element(libvirt_volume.volume.*.id, count.index)
    volume_id = libvirt_volume.volume[each.key].id
  }
  cpu {
    mode = "host-passthrough"
  }

  # Ensures a link between disk and domain, so if domain creation
  # fails, a follow-up destroy removes the disk as well.
  depends_on = [libvirt_cloudinit_disk.cloudinit_disk]

}
