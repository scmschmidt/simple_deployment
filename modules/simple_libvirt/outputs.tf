output "machine_address" {
  value       = libvirt_domain.domain[*].network_interface[0].addresses[0]
  description = "The primary IP address of the first interface of all virtual machines."
  sensitive   = false
}

output "machine_name" {
  value       = libvirt_domain.domain[*].name
  description = "The names of the created virtual machines."
  sensitive   = false
}