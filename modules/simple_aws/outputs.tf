output "machines" {
  value       = aws_instance.instance
  description = "The data of the deployed machines."
  sensitive   = false
}

output "machine_info" {
  value       = {
    for id, data in aws_instance.instance:
      "${data.tags["Name"]}" => {
        "id"         = data.id,
        "size"       = var.machines[id][0],
        "image"      = var.machines[id][1]
        "ip_address" = data.public_ip
      }
    }
  description = "Some aggregated data about deployed machines."
  sensitive   = false
}
