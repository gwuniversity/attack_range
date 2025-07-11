
# Configure the Google Cloud Provider
provider "google" {
  project     = var.gcp.project_id
  region      = var.gcp.region
  zone        = var.gcp.zone
}