
output "machines" {
  value       = aws_instance.instance[*]
  description = "The data of the deployed machines."
  sensitive   = false
}

output "machine_info" {
  value       = {
    for machine in metadata_value.machine_info[*]:
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