output "machine_address" {
  value       = azurerm_linux_virtual_machine.virtual_machine[*].public_ip_address
  description = "The public IP address of the instance."
  sensitive   = false
}

output "machine_name" {
  value       = azurerm_linux_virtual_machine.virtual_machine[*].computer_name
  description = "The names of the instances."
  sensitive   = false
}