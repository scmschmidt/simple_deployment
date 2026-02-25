output "machines" {
  value       = google_compute_instance.linux_vm
  description = "The data of the deployed machines."
  sensitive   = false
}

output "machine_info" {
  value       = {
    for id, data in google_compute_instance.linux_vm:
      "${data.name}" => {
        "id"         = data.id,
        "size"       = var.machines[id][0],
        "image"      = var.machines[id][1]
        "ip_address" = data.network_interface[0].access_config[0].nat_ip
      }
    }
  description = "Some aggregated data about deployed machines."
  sensitive   = false
}
