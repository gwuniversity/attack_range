
# Output Variables for Kali Linux Instance
# These output variables provide essential information about the Kali Server Instance,
# including its name, public IP (if assigned), and internal IP.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# These outputs can be used for verification or additional configuration steps.
# -----------------------------------------------------------------------------
# Output the instance name of the Kali server for easy reference
output "kali_server_instance_name" {
  description = "Name of the Kali Server Instance for identification in GCP"
  value       = google_compute_instance.kali_machine[*].name
}

# Output the public IP address of the Kali Server Instance
# This IP is accessible if an external IP is assigned to the instance
output "kali_server_public_ip" {
  description = "Public IP address of the Kali Server Instance, used for external access"
  value       = google_compute_instance.kali_machine[*].network_interface[0].access_config[0].nat_ip
}

# Output the internal IP address of the Kali Server Instance
# This IP is used for internal communication within the VPC
output "kali_server_internal_ip" {
  description = "Internal IP address of the Kali Server Instance, used for VPC-internal access"
  value       = google_compute_instance.kali_machine[*].network_interface[0].network_ip
}

# Output the instance ID of the Kali Server
# The unique identifier for the created Kali Linux instance
output "kali_instance_id" {
  description = "The instance ID of the Kali Linux server, useful for identifying the resource."
  value       = google_compute_instance.kali_machine[*].id
}

# Output the public SSH key for accessing the Kali Server
# Specifies the public key used to log in to the Kali Linux instance
output "kali_public_key" {
  description = "The public key utilized to SSH into the Kali Linux instance for secure access."
  value       = var.gcp.public_key_path
}
