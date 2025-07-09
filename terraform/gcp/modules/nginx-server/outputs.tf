
# -----------------------------------------------------------------------------
# Output Variables for NGINX Server Instance
# These outputs provide essential details about the NGINX Server Instance,
# including its name, IP addresses, and self-link within Google Cloud Platform.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# These outputs can be used for verification or additional configuration steps.
# -----------------------------------------------------------------------------

# Output: NGINX Server Instance Name
# Provides the name of the NGINX Server Instance for identification.
output "nginx_server_name" {
  description = "The name of the NGINX Server Instance"
  value       = google_compute_instance.nginx_server[*].name
}

# Output: Internal IP of NGINX Server Instance
# Provides the internal IP address, useful for private network communications.
output "nginx_server_internal_ip" {
  description = "The internal IP address of the NGINX Server Instance"
  value       = google_compute_instance.nginx_server[*].network_interface[0].network_ip
}

# Output: External IP of NGINX Server Instance
# Provides the external IP address, if assigned, allowing access from the internet.
output "nginx_server_external_ip" {
  description = "The external IP address of the NGINX Server Instance, if assigned"
  value       = google_compute_instance.nginx_server[*].network_interface[0].access_config[0].nat_ip
}

# Output: Self-Link of NGINX Server Instance
# Provides the self-link of the NGINX server, a URL uniquely identifying this instance in GCP.
output "nginx_server_self_link" {
  description = "The self-link of the NGINX Server Instance"
  value       = google_compute_instance.nginx_server[*].self_link
}

# Output the instance ID of the NGINX Server
# The unique identifier for the created NGINX instance
output "nginx_instance_id" {
  description = "The instance ID of the NGINX server."
  value       = google_compute_instance.nginx_server[*].id
}