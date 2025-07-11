
# VPC Network Outputs
# Provides essential details of the VPC network configuration, including network
# name, IDs, and self-link for integration with other modules and resources.
# -----------------------------------------------------------------------------

# Output the VPC network name
output "vpc_network_name" {
  description = "The name of the VPC network created for the project"
  value       = module.vpc.network_name
}

# Output the ID of the public subnet within the VPC
output "vpc_public_subnet_id" {
  description = "The ID of the public subnet in the VPC"
  value       = module.vpc.subnets_ids[0]
}

# Output the ID of the private subnet within the VPC
# output "vpc_private_subnet_id" {
#   description = "The ID of the private subnet in the VPC"
#   value       = module.vpc.subnets_ids[1]
# }

# Output the unique identifier for the VPC network
output "vpc_network_id" {
  description = "The unique ID of the VPC network"
  value       = module.vpc.network_id
}

# Output the full self-link of the VPC network, which is useful for referencing the network in other GCP resources
output "vpc_network_self_link" {
  description = "The full self-link URI of the VPC network for cross-module references"
  value       = module.vpc.network_self_link
}

# -----------------------------------------------------------------------------
# Splunk Server IP Output
# Provides the public IP address of the Splunk server for external access.
# -----------------------------------------------------------------------------

# Output the public IP address of the Splunk server instance
output "splunk_server_ip" {
  description = "The static public IP address of the Splunk server instance"
  value       = google_compute_address.static_ip.address
}

# Output the first 3 octects value of the private cidr block
# output "private_three_octets" {
#   value = local.private_cidr_three_octets
# }