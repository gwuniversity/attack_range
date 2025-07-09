# Output for service account emails created by Terraform
# This output provides a map where the keys are the names of the service accounts,
# and the values are their corresponding email addresses.
output "service_account_emails" {
  description = "Map of created service account emails. Each key represents the service account name, and the corresponding value is the service account's email address."
  value = {
    # Using a for expression to iterate over each created service account resource
    # (google_service_account.accounts) and map the account name (sa_name) to its email address (sa.email).
    for sa_name, sa in google_service_account.accounts : sa_name => sa.email
  }
}

# Output for assigned roles for each service account
# This output provides a map where the keys are the names of the service accounts,
# and the values are lists of roles assigned to each account, as specified in the 'service_accounts' variable.
output "assigned_roles" {
  description = "Map of service accounts to their assigned roles. Each key represents the service account name, and the corresponding value is a list of roles assigned to that account."
  value = {
    # Iterating over the input variable 'service_accounts' which holds the details of each account,
    # mapping each account name (sa_name) to its assigned roles (sa_details.roles).
    for sa_name, sa_details in var.service_accounts : sa_name => sa_details.roles
  }
}
