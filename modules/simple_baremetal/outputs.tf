output "machines" {
  value       = null_resource.machine
  description = "The data of the bare-metal machines."
  sensitive   = false
}

output "machine_info" {
  value       = {
    for id, data in null_resource.machine:
      "${id}" => data.triggers.address
    }
  description = "Some data of bare-metal machines."
}