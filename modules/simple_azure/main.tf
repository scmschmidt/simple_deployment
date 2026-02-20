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
  image_map  = yamldecode(file("${path.root}/images_azure.yaml"))
  sizing_map = yamldecode(file("${path.root}/sizing_azure.yaml"))

  # Load cloud-init template.
  cloudinit_template = fileexists("${path.root}/cloudinit.user-data.tftpl") ? "${path.root}/cloudinit.user-data.tftpl" : "${path.module}/cloudinit.user-data.tftpl"

  # Common tags.
  tags = {
    owner = var.owner_tag
    managed_by = var.managed_by_tag
    application = var.application_tag
  }
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
  
  lifecycle {
    ignore_changes = [ 
      tags["Cost Center"],
      tags["Department"],
      tags["Environment"],
      tags["Finance Business Partner"],
      tags["General Ledger Code"],
      tags["Group"],
      tags["Owner"],
      tags["Stakeholder"]
    ]
  }
  tags = local.tags
}

# Create virtual network.
resource "azurerm_virtual_network" "network" {
  name                = "${var.name}-network"
  address_space       = [var.subnet]
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  tags                = local.tags
  lifecycle {
    ignore_changes = [ 
      tags["Cost Center"],
      tags["Department"],
      tags["Environment"],
      tags["Finance Business Partner"],
      tags["General Ledger Code"],
      tags["Group"],
      tags["Owner"],
      tags["Stakeholder"]
    ]
  }
}

# Create private subnet.
resource "azurerm_subnet" "subnet" {
  name                 = "${var.name}-subnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = [var.subnet]
}

# Create public IPs for machines.
resource "azurerm_public_ip" "public_ip" {
  for_each            = length(var.bastion) == 0 ? local.machine_ids : toset([])
  name                = "${var.name}-public_ip-${each.key}"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  allocation_method   = "Static"    # required by standard sku
  sku                 = "Standard"  # required by NAT gateway
  tags                = local.tags
  lifecycle {
    ignore_changes = [ 
      tags["Cost Center"],
      tags["Department"],
      tags["Environment"],
      tags["Finance Business Partner"],
      tags["General Ledger Code"],
      tags["Group"],
      tags["Owner"],
      tags["Stakeholder"]
    ]
  }
}

# Create public IP for bastion host.
resource "azurerm_public_ip" "public_ip_bastion" {
  count               = length(var.bastion) == 0 ? 0 : 1
  name                = "${var.name}-public_ip-bastion"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  allocation_method   = "Static"    # required by standard sku
  sku                 = "Standard"  # required by NAT gateway
  tags                = local.tags
  lifecycle {
    ignore_changes = [ 
      tags["Cost Center"],
      tags["Department"],
      tags["Environment"],
      tags["Finance Business Partner"],
      tags["General Ledger Code"],
      tags["Group"],
      tags["Owner"],
      tags["Stakeholder"]
    ]
  }
}

# Create public IP for NAT gateway.
resource "azurerm_public_ip" "public_ip_nat_gateway" {
  count               = length(var.bastion) == 0 ? 0 : 1
  name                = "${var.name}-public_ip-nat_gateway"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  allocation_method   = "Static"    # required by standard sku
  sku                 = "Standard"  # required by NAT gateway
  tags                = local.tags
  lifecycle {
    ignore_changes = [ 
      tags["Cost Center"],
      tags["Department"],
      tags["Environment"],
      tags["Finance Business Partner"],
      tags["General Ledger Code"],
      tags["Group"],
      tags["Owner"],
      tags["Stakeholder"]
    ]
  }
}

# Create NAT gateway.
resource "azurerm_nat_gateway" "nat_gateway" {
  count               = length(var.bastion) == 0 ? 0 : 1
  name                = "${var.name}-nat_gateway"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  tags                = local.tags
  lifecycle {
    ignore_changes = [ 
      tags["Cost Center"],
      tags["Department"],
      tags["Environment"],
      tags["Finance Business Partner"],
      tags["General Ledger Code"],
      tags["Group"],
      tags["Owner"],
      tags["Stakeholder"]
    ]
  } 
}

# Associate NAT gateway with its public IP and subnet.
resource "azurerm_nat_gateway_public_ip_association" "ng2pip" {
  count                = length(var.bastion) == 0 ? 0 : 1
  nat_gateway_id       = azurerm_nat_gateway.nat_gateway[count.index].id
  public_ip_address_id = azurerm_public_ip.public_ip_nat_gateway[count.index].id
}
resource "azurerm_subnet_nat_gateway_association" "ng2snet" {
  count                = length(var.bastion) == 0 ? 0 : 1
  subnet_id            = azurerm_subnet.subnet.id
  nat_gateway_id       = azurerm_nat_gateway.nat_gateway[count.index].id
}

# Create network interface.
resource "azurerm_network_interface" "bastion_network_interface" {
  count               = length(var.bastion) == 0 ? 0 : 1
  name                = "${var.name}-bastion"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  ip_configuration {
    name                          = "${var.name}-ip_configuration"
    subnet_id                     = azurerm_subnet.subnet.id
    public_ip_address_id          = azurerm_public_ip.public_ip_bastion[count.index].id
    private_ip_address_allocation = "Dynamic"
  }
  tags                = local.tags

  lifecycle {
    ignore_changes = [ 
      tags["Cost Center"],
      tags["Department"],
      tags["Environment"],
      tags["Finance Business Partner"],
      tags["General Ledger Code"],
      tags["Group"],
      tags["Owner"],
      tags["Stakeholder"]
    ]
  }  
}

# Connect the security group to the bastion host network interfaces.
resource "azurerm_network_interface_security_group_association" "network_interface_security_group_association_bastion" {
  count                     = length(var.bastion) == 0 ? 0 : 1
  network_interface_id      = azurerm_network_interface.bastion_network_interface[count.index].id
  network_security_group_id = azurerm_network_security_group.security_group.id
}

# Bastion virtual machine.
resource "azurerm_linux_virtual_machine" "bastion_virtual_machine" {
  count               = length(var.bastion) == 0 ? 0 : 1
  name                = "${var.name}-bastion"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  size                = local.sizing_map[var.bastion[0]]

  custom_data = base64encode(templatefile(local.cloudinit_template, { 
    keymap = var.keymap,
    admin_username = var.admin_user, 
    admin_user_key = local.bastion_definition[2], 
    subscription_registration_key = local.bastion_definition[3],
    registration_server = var.registration_server,
    enable_root_login = var.enable_root_login ? 1 : 0
  }))

  # Azure requires an admin user even we use cloud-init to deploy the admin user.
  # (The user gets disabled by cloud-init even I did not found it on the provisioned system.)
  admin_username                  = "dummyadmin"
  admin_password                  = join("", [base64encode("bastion"), "123QWEasd#?"])
  disable_password_authentication = false

  license_type = "SLES_BYOS"
  network_interface_ids = [
    azurerm_network_interface.bastion_network_interface[count.index].id
  ]

  os_disk {
    caching              = "None"
    storage_account_type = "Standard_LRS"
    #disk_size_gb        = ""
  }

  # The source image to use.additional_capabilities {
  source_image_reference {
    publisher = split(":", local.image_map[var.bastion[1]])[0]
    offer     = split(":", local.image_map[var.bastion[1]])[1]
    sku       = split(":", local.image_map[var.bastion[1]])[2]
    version   = "latest"
  }

  tags                = local.tags
  lifecycle {
    ignore_changes = [ 
      tags["Cost Center"],
      tags["Department"],
      tags["Environment"],
      tags["Finance Business Partner"],
      tags["General Ledger Code"],
      tags["Group"],
      tags["Owner"],
      tags["Stakeholder"]
    ]
  }
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

  security_rule {
    name                        = "ICMP"
    priority                    = 1002
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "Icmp"
    source_port_range           = "*"
    destination_port_range      = "*"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
  }

  tags                = local.tags

  lifecycle {
    ignore_changes = [ 
      tags["Cost Center"],
      tags["Department"],
      tags["Environment"],
      tags["Finance Business Partner"],
      tags["General Ledger Code"],
      tags["Group"],
      tags["Owner"],
      tags["Stakeholder"]
    ]
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
    public_ip_address_id          = length(var.bastion) == 0 ? azurerm_public_ip.public_ip[each.key].id : null
  }

  tags                = local.tags
  lifecycle {
    ignore_changes = [ 
      tags["Cost Center"],
      tags["Department"],
      tags["Environment"],
      tags["Finance Business Partner"],
      tags["General Ledger Code"],
      tags["Group"],
      tags["Owner"],
      tags["Stakeholder"]
    ]
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
  for_each            = local.machine_ids
  name                = "${var.name}-${each.key}"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  size                = local.sizing_map[local.machine_definitions[each.key][0]]

  custom_data = base64encode(templatefile(local.cloudinit_template, { 
    keymap = var.keymap,
    admin_username = var.admin_user, 
    admin_user_key = local.machine_definitions[each.key][2], 
    subscription_registration_key = local.machine_definitions[each.key][3],
    registration_server = var.registration_server,
    enable_root_login = var.enable_root_login ? 1 : 0
  }))

  # Azure requires an admin user even we use cloud-init to deploy the admin user.
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
    publisher = split(":", local.image_map[local.machine_definitions[each.key][1]])[0]
    offer     = split(":", local.image_map[local.machine_definitions[each.key][1]])[1]
    sku       = split(":", local.image_map[local.machine_definitions[each.key][1]])[2]
    version   = "latest"
  }

  tags                = local.tags
  lifecycle {
    ignore_changes = [ 
      tags["Cost Center"],
      tags["Department"],
      tags["Environment"],
      tags["Finance Business Partner"],
      tags["General Ledger Code"],
      tags["Group"],
      tags["Owner"],
      tags["Stakeholder"]
    ]
  }
}
