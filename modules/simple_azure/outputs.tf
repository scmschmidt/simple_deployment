output "machines" {
  value       = azurerm_linux_virtual_machine.virtual_machine
  description = "The data of the deployed machines."
  sensitive   = false
}

output "machine_info" {
  value       = {
    for id, data in azurerm_linux_virtual_machine.virtual_machine:
      "${data.name}" => {
        "id"         = data.id,
        "size"       = var.machines[id][0],
        "image"      = var.machines[id][1]
        #"ip_address" = data.public_ip_address
        "ip_address" = data.public_ip_address != null && data.public_ip_address != "" ? data.public_ip_address  : data.private_ip_address
      }
    }
  description = "Some aggregated data about deployed machines."
  sensitive   = false
}

output "bastion_info" {
  value = {
    "id"                  = one(azurerm_linux_virtual_machine.bastion_virtual_machine[*].id),
    "size"                = length(var.bastion) > 0 ?  var.bastion[0] : "",
    "image"               = length(var.bastion) > 0 ?  var.bastion[1] : "",
    "public_ip_address"   = join("", azurerm_linux_virtual_machine.bastion_virtual_machine[*].public_ip_address),
    "private_ip_address"  = join("", azurerm_linux_virtual_machine.bastion_virtual_machine[*].private_ip_address)
  }
  description = "Some aggregated data about the bastion host."
  sensitive   = false
}
