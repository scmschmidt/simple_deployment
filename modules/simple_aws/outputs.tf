
output "machine_address" {
  value       = aws_instance.instance[*].public_ip
  description = "The public IP address of the instance."
  sensitive   = false
}

output "machine_name" {
  value       = aws_instance.instance[*].tags.Name
  description = "The names of the instances."
  sensitive   = false
}