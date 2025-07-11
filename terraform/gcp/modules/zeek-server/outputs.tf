
# -----------------------------------------------------------------------------
# Outputs for Zeek Server Configuration
# -----------------------------------------------------------------------------
# This section defines output values for the Zeek server and its associated
# packet mirroring configuration in Google Cloud Platform (GCP). Outputs include
# instance details, network configuration, and mirroring collector information.
# These outputs allow easy access to the server's details and status from the
# Terraform console and other automated processes.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# These outputs can be used for verification or additional configuration steps.
# -----------------------------------------------------------------------------

# Output: Zeek Server Instance Name
output "zeek_server_name" {
  description = "The name of the Zeek Server Instance"
  value       = google_compute_instance.zeek_sensor[*].name
}

# Output: Zeek Server Internal IP
output "zeek_server_internal_ip" {
  description = "The internal IP address of the Zeek Server Instance"
  value       = google_compute_instance.zeek_sensor[*].network_interface[0].network_ip
}

# Output: Zeek Server External IP
output "zeek_server_external_ip" {
  description = "The external IP address of the Zeek Server Instance, if assigned"
  value       = google_compute_instance.zeek_sensor[*].network_interface[0].access_config[0].nat_ip
}

# Output the instance ID of the Zeek Server
# The unique identifier for the created Zeek instance
output "zeek_instance_id" {
  description = "The instance ID of the Zeek server."
  value       = google_compute_instance.zeek_sensor[*].id
}