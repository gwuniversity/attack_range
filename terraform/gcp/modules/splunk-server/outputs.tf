
# -----------------------------------------------------------------------------
# Splunk Server Outputs
# These outputs provide essential information about the Splunk server instance,
# including the public IP address and the instance name. They can be used to 
# reference or verify the deployment in other modules or in deployment scripts.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# These outputs can be used for verification or additional configuration steps.
# -----------------------------------------------------------------------------

# Output: Splunk Service Account Email
# Provides the email address of the Splunk Service Account, if created
# output "splunk_sa_email" {
#   description = "The email address of the Splunk Service Account"
#   value       = var.splunk_sa_email
# }

# # Output: Splunk Server Roles
# # Lists the roles assigned to the Splunk Service Account, if created
# output "splunk_sa_roles" {
#   description = "Roles assigned to the Splunk Service Account"
#   value       = var.splunk_sa_roles
# }

# Output for the Public IP of the Splunk Server
output "splunk_server_ip" {
  description = "Public IP of the Splunk server instance in GCP"
  value       = google_compute_address.splunk_ip[*].address
}

# Output for the Name of the Splunk Server
output "splunk_server_name" {
  description = "Name of the Splunk server instance in GCP"
  value       = google_compute_instance.splunk_server[*].name
}

# Output the instance ID of the Splunk Server
# The unique identifier for the created Splunk instance
output "splunk_instance_id" {
  description = "The instance ID of the Splunk server."
  value       = google_compute_instance.splunk_server[*].id
}
