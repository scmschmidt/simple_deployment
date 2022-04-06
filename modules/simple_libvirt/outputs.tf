output "machines" {
  value       = libvirt_domain.domain[*]
  description = "The data of the deployed machines."
  sensitive   = false
}
   /* 
output "machine_info" {

  value = {
    for machine, data in metadata_value.machine_info[*]:
      "${machine}" => data
  }

  value       = {
    for machine in metadata_value.machine_info[0]:
      "${machine.outputs.name}" => {
        "id"         = machine.outputs.id,
        "size"       = machine.outputs.size,
        "image"      = machine.outputs.image
        "ip_address" = machine.outputs.ip_address
      }
    }

  description = "Some aggregated data about deployed machines."
  sensitive   = false
}
  */


  output "machine_info" {
  value       = {
    for id, data in libvirt_domain.domain:
      "${data.name}" => {
        "id"         = data.id,
        "size"       = var.machines[id][0],
        "image"      = var.machines[id][1]
        "ip_address" = data.network_interface[0].addresses[0]
      }
    }
  description = "Some aggregated data about deployed machines."
  sensitive   = false
}
