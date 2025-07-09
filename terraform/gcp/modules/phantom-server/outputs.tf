
# -----------------------------------------------------------------------------
# Outputs for Phantom Server Instance in GCP
# These outputs provide useful information about the Phantom Server Instance,
# such as its name, IP addresses (internal and external), and self-link.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# These outputs can be used for verification or additional configuration steps.
# -----------------------------------------------------------------------------

# Output: Name of the Phantom Server Instance
output "phantom_server_name" {
  description = "The name of the Phantom Server Instance"
  value       = google_compute_instance.phantom_server[*].name
}

# Output: Internal IP of the Phantom Server Instance
output "phantom_server_internal_ip" {
  description = "The internal IP address of the Phantom Server Instance"
  value       = google_compute_instance.phantom_server[*].network_interface[0].network_ip
}

# Output: External IP of the Phantom Server Instance (if assigned)
output "phantom_server_external_ip" {
  description = "The external IP address of the Phantom Server Instance, if assigned"
  value       = google_compute_instance.phantom_server[*].network_interface[0].access_config[0].nat_ip
}

# Output: Self-link of the Phantom Server Instance for direct reference in GCP
output "phantom_server_self_link" {
  description = "The self-link of the Phantom Server Instance"
  value       = google_compute_instance.phantom_server[*].self_link
}

# Output the instance ID of the Panthom Server
# The unique identifier for the created Panthom instance
output "phantom_instance_id" {
  description = "The instance ID of the Panthom server."
  value       = try(google_compute_instance.phantom_server[*].id, "")
}

# Output the public SSH key for accessing the Panthom Server
# Specifies the public key used to log in to the Panthom instance
output "phantom_public_key" {
  description = "The public key utilized to ssh login to phantom server."
  value       = var.gcp.public_key_path
}