output "machines" {
  value       = null_resource.machine
  description = "The data of the bare-metal machines."
  sensitive   = false
}

