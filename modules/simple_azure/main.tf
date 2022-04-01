# Here some important locals to make it easier to change certain things.
locals {
  image_map  = yamldecode(file("${path.root}/images_azure.yaml"))
  sizing_map = yamldecode(file("${path.root}/sizing_azure.yaml"))
  image_urn  = local.image_map[var.image]
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
  count               = var.amount
  name                = "${var.name}-public_ip-${count.index}"
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
  count               = var.amount
  name                = "${var.name}-network_interface-${count.index}"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  ip_configuration {
    name                          = "${var.name}-ip_configuration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(azurerm_public_ip.public_ip.*.id, count.index)
  }
}

# Connect the security group to the network interfaces.
resource "azurerm_network_interface_security_group_association" "network_interface_security_group_association" {
  count                     = var.amount
  network_interface_id      = element(azurerm_network_interface.network_interface.*.id, count.index)
  network_security_group_id = azurerm_network_security_group.security_group.id
}

# And finally create the virtual machines.
resource "azurerm_linux_virtual_machine" "virtual_machine" {
  count               = var.amount
  name                = "${var.name}-${count.index}"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  size                = local.sizing_map[var.size]

  custom_data = base64encode(local.cloudinit_userdata)

  # Azure reuquires an admin user even we use cloud-init to deploy the admin user.
  # (The user gets disabled by cloud-init even I did not found it on the provisioned system.)
  admin_username                  = "dummyadmin"
  admin_password                  = join("", [base64encode(timestamp()), "123QWEasd#?"])
  disable_password_authentication = false

  license_type = "SLES_BYOS"
  network_interface_ids = [
    element(azurerm_network_interface.network_interface.*.id, count.index)
  ]

  os_disk {
    caching              = "None"
    storage_account_type = "Standard_LRS"
    #disk_size_gb        = ""
  }

  # The source image to use.additional_capabilities {
  source_image_reference {
    publisher = split(":", local.image_urn)[0]
    offer     = split(":", local.image_urn)[1]
    sku       = split(":", local.image_urn)[2]
    version   = "latest"
  }
}