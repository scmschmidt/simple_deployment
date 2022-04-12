output "machines" {
  value       = libvirt_domain.domain
  description = "The data of the deployed machines."
  sensitive   = false
}

output "machine_info" {
  value       = {
    for id, data in libvirt_domain.domain:
      "${data.name}" => {
        "id"         = data.id
        "size"       = var.machines[id][0]
        "image"      = var.machines[id][1]
        "ip_address" = try(data.network_interface[0].addresses[0], "")
      }
    }
  description = "Some aggregated data about deployed machines."
  sensitive   = false
}
