
# Resource to create multiple Google Cloud service accounts
# This resource iterates over the 'service_accounts' variable to create each specified service account.
resource "google_service_account" "accounts" {
  # 'for_each' allows creating a service account for each entry in 'service_accounts' map
  for_each = var.service_accounts

  # Unique identifier for the service account; based on the 'account_id' in each 'service_accounts' entry
  account_id = each.value.account_id

  # Display name for the service account, helpful for human-readable identification in the Cloud Console
  display_name = "Service Account for ${each.key}"
}

# Resource to assign IAM roles to each service account
# This resource binds specified IAM roles to each service account created in the 'google_service_account' resource.
resource "google_project_iam_member" "bindings" {
  # 'for_each' is used to iterate over each service account to assign multiple roles.
  # We create a map with each service account name (sa_name) mapped to a structure containing
  # the email of the created service account and its list of roles from 'service_accounts'.
  for_each = {
    for sa_name, sa_details in var.service_accounts : sa_name => {
      email = google_service_account.accounts[sa_name].email
      roles = sa_details.roles
    }
  }

  # Google Cloud project ID to which these IAM roles will be assigned
  project = var.gcp.project_id

  # IAM member being assigned the roles, which is the service account identified by its email
  member = "serviceAccount:${each.value.email}"

  # Assigning the first role in the list of roles associated with each service account.
  # If multiple roles are to be assigned, consider using a separate resource to handle each role.
  role = element(each.value.roles, 0)
}
