output "instance_id" {
  description = "The instance ID of the Zeek server"
  value       = var.zeek_server.zeek_server == "1" ? aws_instance.zeek_sensor[0].id : null
}

output "network_interface_id" {
  description = "The primary network interface ID of the Zeek server"
  value       = var.zeek_server.zeek_server == "1" ? aws_instance.zeek_sensor[0].primary_network_interface_id : null
}