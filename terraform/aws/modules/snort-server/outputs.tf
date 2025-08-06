output "instance_id" {
  description = "The instance ID of the Snort server"
  value       = var.snort_server.snort_server == "1" ? aws_instance.snort_sensor[0].id : null
}

output "network_interface_id" {
  description = "The primary network interface ID of the Snort server"
  value       = var.snort_server.snort_server == "1" ? aws_instance.snort_sensor[0].primary_network_interface_id : null
}