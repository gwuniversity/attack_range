
# -----------------------------------------------------------------------------
# Snort Server Output Variables
# These output variables provide key information about the Snort server 
# instance, including its name, IP addresses, self-links, and associated 
# network configurations. These outputs allow easy access to essential 
# attributes of the Snort instance and related GCP resources.
# --------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# These outputs can be used for verification or additional configuration steps.
# -----------------------------------------------------------------------------

# Output: Snort Server Internal IP Address
output "snort_server_internal_ip" {
  description = "The internal IP address of the Snort Server Instance"
  value       = google_compute_instance.snort_sensor[*].network_interface[0].network_ip
}

# Output: Snort Server External IP Address
output "snort_server_external_ip" {
  description = "The external IP address of the Snort Server Instance, if assigned"
  value       = google_compute_instance.snort_sensor[*].network_interface[0].access_config[0].nat_ip
}

# Output: Self-Link for Snort Sensor Instances
output "snort_server_self_links" {
  description = "Self-links for Snort sensor instances"
  value       = google_compute_instance.snort_sensor[*].self_link
}

