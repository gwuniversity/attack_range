
# Description: This configuration file provisions a Kali Linux instance in Google Cloud Platform (GCP),
# including necessary resources such as the Compute Engine instance, boot disk configuration, network interface,
# SSH access, and an optional static external IP address.

# -----------------------------------------------------------------------------
# Kali Linux Instance Configuration
# -----------------------------------------------------------------------------

# Kali Linux instance configuration in GCP
resource "google_compute_instance" "kali_machine" {
  # Instance is created only if 'kali_server' variable is set to 1
  count        = var.kali_server.kali_server == 1 ? 1 : 0
  name         = "${var.general.attack_range_name}-kali-server-${var.general.key_name}"
  machine_type = "e2-standard-2"         # Specify the machine type for Kali Linux instance
  zone         = var.gcp.zone                          # Specify GCP zone for instance deployment

  # Configure the boot disk with the custom Kali Linux image
  boot_disk {
    initialize_params {
      image = "kali-linux-image"                 # ID of the custom Kali Linux image in GCP
      size  = 30              # Disk size in GB (customizable per requirements)
      type  = "pd-ssd"               # Disk type, e.g., pd-standard or pd-ssd
    }
    auto_delete = true                                 # Disk is deleted when instance is deleted
  }

  # Network interface configuration for internal and external IP setup
  network_interface {
    network    = var.vpc_network                       # VPC network to attach the instance to
    subnetwork = var.subnetwork                        # Subnetwork in which the instance resides
    network_ip = "10.0.1.30"            # Internal static IP address, if specified
    
    access_config {                                    # Attach an external IP if required
      nat_ip = length(google_compute_address.kali_ip) > count.index ? google_compute_address.kali_ip[count.index].address : null
    }
  }

  # Use local-exec provisioner to clean known_hosts
  provisioner "local-exec" {
    command = "ssh-keygen -f ~/.ssh/known_hosts -R ${self.network_interface.0.access_config.0.nat_ip}"
  }

  # SSH configuration for secure access
  metadata = {
    ssh-keys = "kali:${file(var.gcp.public_key_path)}" # SSH public key for 'kali' user access
  }
  metadata_startup_script = <<-EOT
    #!/bin/bash
    mkdir -p /home/kali/.ssh
    echo '${file(var.gcp.public_key_path)}' > /home/kali/.ssh/authorized_keys
    chown -R kali:kali /home/kali/.ssh
    chmod 600 /home/kali/.ssh/authorized_keys
  EOT

  # Instance tags for easy identification and network management
  tags = ["gcp-infrastructure", "kali-linux", "attack-range", "ssh"]

  # Labels (metadata tags) for resource organization and tracking
  labels = {
    name = "ar-kali-${var.general.key_name}-${var.general.attack_range_name}-${count.index}"
  }

  # Provisioner for initial boot verification via SSH
  provisioner "remote-exec" {
    inline = ["echo booted"]

    connection {
      type        = "ssh"
      user        = "kali"                            # SSH username
      host        = self.network_interface[0].access_config[0].nat_ip # External IP for SSH connection
      private_key = file(var.gcp.private_key_path)    # SSH private key for connection
    }
  }
}

# -----------------------------------------------------------------------------
# External IP Address Configuration for Kali Linux Instance
# -----------------------------------------------------------------------------
resource "google_compute_address" "kali_ip" {
  # Only create an external IP if 'kali_server' and 'use_elastic_ips' are enabled
  count  = (var.kali_server.kali_server == 1) && (var.gcp.use_static_ip == "1") ? 1 : 0
  name   = "kali-ip-${count.index}"                   # Unique name for the external IP address
  region = var.gcp.region                             # GCP region for the external IP allocation
}
