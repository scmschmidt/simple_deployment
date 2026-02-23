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
        "ip_address" = data.public_ip != null && data.public_ip != "" ? data.public_ip  : data.private_ip
      }
    }
  description = "Some aggregated data about deployed machines."
  sensitive   = false
}

# output "bastion_info" {
#   value = {
#     "id"                  = one(aws_instance.bastion_virtual_machine[*].id),
#     "size"                = length(var.bastion) > 0 ?  var.bastion[0] : "",
#     "image"               = length(var.bastion) > 0 ?  var.bastion[1] : "",
#     "public_ip_address"   = join("", aws_instance.bastion_virtual_machine[*].public_ip_address),
#     "private_ip_address"  = join("", aws_instance.bastion_virtual_machine[*].private_ip_address)
#   }
#   description = "Some aggregated data about the bastion host."
#   sensitive   = false
# }

output "debug" { value = local.image_map[local.machine_definitions["1"][1]] }