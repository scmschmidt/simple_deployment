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
        "ip_address" = length(data.network_interface[0].access_config) > 0 ? data.network_interface[0].access_config[0].nat_ip : data.network_interface[0].network_ip
      }
    }
  description = "Some aggregated data about deployed machines."
  sensitive   = false
}

output "bastion_info" {
  value = {
    "id"                  = one(google_compute_instance.bastion[*].id),
    "size"                = length(var.bastion) > 0 ?  var.bastion[0] : "",
    "image"               = length(var.bastion) > 0 ?  var.bastion[1] : "",
    "public_ip_address"   = join("", google_compute_instance.bastion[*].network_interface[0].access_config[0].nat_ip),
    "private_ip_address"  = join("", google_compute_instance.bastion[*].network_interface[0].network_ip)
  }
  description = "Some aggregated data about the bastion host."
  sensitive   = false
}