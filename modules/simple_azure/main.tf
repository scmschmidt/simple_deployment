# Here some important locals to make it easier to change certain things.
locals {
  machine_ids = toset(keys(var.machines))
  image_map  = yamldecode(file("${path.root}/images_azure.yaml"))
  sizing_map = yamldecode(file("${path.root}/sizing_azure.yaml"))
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
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

# The resource group to bind them all...
resource "azurerm_resource_group" "resource_group" {
  name     = "${var.name}-resource_group"
  location = var.location
}

# Create virtual network.
resource "azurerm_virtual_network" "network" {
  name                = "${var.name}-network"
  address_space       = [var.subnet]
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
}

# Create subnet.
resource "azurerm_subnet" "subnet" {
  name                 = "${var.name}-subnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = [var.subnet]
}

# Create public IPs
resource "azurerm_public_ip" "public_ip" {
  for_each            = local.machine_ids
  name                = "${var.name}-public_ip-${each.key}"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  allocation_method   = "Dynamic"
}

# Create network security group and rule.
resource "azurerm_network_security_group" "security_group" {
  name                = "${var.name}-security_group"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interfaces.
resource "azurerm_network_interface" "network_interface" {
  for_each            = local.machine_ids
  name                = "${var.name}-network_interface-${each.key}"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  ip_configuration {
    name                          = "${var.name}-ip_configuration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip[each.key].id
  }
}

# Connect the security group to the network interfaces.
resource "azurerm_network_interface_security_group_association" "network_interface_security_group_association" {
  for_each                  = local.machine_ids
  network_interface_id      = azurerm_network_interface.network_interface[each.key].id
  network_security_group_id = azurerm_network_security_group.security_group.id
}

# And finally create the virtual machines.
resource "azurerm_linux_virtual_machine" "virtual_machine" {
  for_each      = local.machine_ids
  name                = "${var.name}-${each.key}"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  size                = local.sizing_map[var.machines[each.key][0]]

  custom_data = base64encode(local.cloudinit_userdata)

  # Azure reuquires an admin user even we use cloud-init to deploy the admin user.
  # (The user gets disabled by cloud-init even I did not found it on the provisioned system.)
  admin_username                  = "dummyadmin"
  admin_password                  = join("", [base64encode(each.key), "123QWEasd#?"])
  disable_password_authentication = false

  license_type = "SLES_BYOS"
  network_interface_ids = [
    azurerm_network_interface.network_interface[each.key].id
  ]

  os_disk {
    caching              = "None"
    storage_account_type = "Standard_LRS"
    #disk_size_gb        = ""
  }

  # The source image to use.additional_capabilities {
  source_image_reference {
    publisher = split(":", local.image_map[var.machines[each.key][1]])[0]
    offer     = split(":", local.image_map[var.machines[each.key][1]])[1]
    sku       = split(":", local.image_map[var.machines[each.key][1]])[2]
    version   = "latest"
  }
}
