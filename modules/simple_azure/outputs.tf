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
        "ip_address" = data.public_ip_address
      }
    }
  description = "Some aggregated data about deployed machines."
  sensitive   = false
}
