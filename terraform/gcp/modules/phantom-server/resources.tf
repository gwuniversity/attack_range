# -----------------------------------------------------------------------------
# Phantom Server Instance Configuration on CentOS 7 in GCP
# This configuration creates a Phantom server instance in Google Cloud Platform,
# including network and disk settings, provisioning, and Ansible setup.
# -----------------------------------------------------------------------------

data "google_compute_image" "phantom_server" {
  count   = var.phantom_server.phantom_server == 1 ? 1 : 0
  family  = "rhel-9"
  project = "rhel-cloud"
}

# Define the Phantom server instance
resource "google_compute_instance" "phantom_server" {
  count        = var.phantom_server.phantom_server == 1 ? 1 : 0
  name         = "${var.general.attack_range_name}-phantom-server-${var.general.key_name}"
  machine_type = "e2-standard-4"  # Machine type for the instance, e.g., "t3.xlarge"
  zone         = var.gcp.zone                      # GCP zone where the instance will be launched

  # Configure the boot disk with CentOS image, disk size, and type
  boot_disk {
    initialize_params {
      image = data.google_compute_image.phantom_server[count.index].self_link      
      size  = 40       # Disk size in GB
      type  = "pd-standard"       # Disk type, e.g., "gp2" equivalent
    }
    auto_delete = true                             # Automatically delete the disk when the instance is deleted
  }

  # Network interface configuration
  network_interface {
    network    = var.vpc_network                   # VPC network to associate with the instance
    subnetwork = var.subnetwork                    # Subnetwork within the VPC
    network_ip = "10.0.1.13"     # Static internal IP if required

    # Optional external IP assignment (using Elastic IPs if configured)
    access_config {
      nat_ip = length(google_compute_address.phantom_ip) > count.index ? google_compute_address.phantom_ip[count.index].address : null
    }
  }

  # Use local-exec provisioner to clean known_hosts
  provisioner "local-exec" {
      command = <<-EOT
          mkdir -p ~/.ssh
          touch ~/.ssh/known_hosts
          ssh-keygen -f ~/.ssh/known_hosts -R ${self.network_interface.0.access_config.0.nat_ip}
      EOT
  }

  # Assign the Phantom Service Account to this instance
    # service_account {
    #     email  = var.phantom_sa_email
    #     scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    # }

  # Metadata for SSH access setup
  metadata = {
    ssh-keys = "root:${file(var.gcp.public_key_path)}"  # Public key for SSH access
  }
  metadata_startup_script = <<-EOT
    #!/bin/bash
    # Ensure SSH directory exists with correct permissions
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    
    # Set up authorized_keys with proper permissions
    echo '${file(var.gcp.public_key_path)}' > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    chown -R root:root /root/.ssh
    
    # Ensure SSH service is running and enabled
    systemctl enable sshd
    systemctl start sshd
    
    # Configure SSH daemon to allow root login with key
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    systemctl restart sshd
  EOT

  # Tags and labels for instance organization and firewall rule association
  tags = ["gcp-infrastructure", "phantom-server", "attack-range", "ssh"]  # Tags for instance categorization
  labels = {
    name = "ar-phantom-${var.general.key_name}-${var.general.attack_range_name}"  # Labels for GCP metadata
  }

  # Remote-exec provisioner to confirm server initialization
  provisioner "remote-exec" {
    inline = [
      # Confirm the instance has booted successfully
      "echo booted",

      # Ensure .ssh directory exists with correct permissions
      "mkdir -p /root/.ssh && chmod 700 /root/.ssh",

      # Ensure authorized_keys file exists with correct permissions
      "touch /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys",

      # Append the public key only if it doesn't already exist in authorized_keys
      "grep -qxF \"$(cat ${file(var.gcp.public_key_path)})\" /root/.ssh/authorized_keys || echo $(cat ${file(var.gcp.public_key_path)}) >> /root/.ssh/authorized_keys"
    ]

    connection {                                   # SSH connection configuration for provisioner
      type        = "ssh"
      user        = "root"
      host        = self.network_interface[0].access_config[0].nat_ip
      private_key = file(var.gcp.private_key_path)
    }
  }

  # Local-exec provisioner to prepare Ansible variables for Phantom server setup
  provisioner "local-exec" {
    working_dir = "../ansible"                     # Directory for Ansible playbook execution
    command = <<-EOT
      cat > vars/phantom_vars.json << 'EOF'
      {
        "general": ${jsonencode(var.general)},
        "gcp": ${jsonencode(var.gcp)},
        "phantom_server": ${jsonencode(var.phantom_server)}
      }
      EOF
    EOT
  }

  # Local-exec provisioner to run the Ansible playbook for server configuration
  provisioner "local-exec" {
    working_dir = "../ansible"
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u root --private-key '${var.gcp.private_key_path}' -i '${self.network_interface[0].access_config[0].nat_ip},' phantom_server.yml -e @vars/phantom_vars.json"
  }
}

# Allocate a static external IP for the Phantom server if configured to use Elastic IPs
resource "google_compute_address" "phantom_ip" {
  count  = (var.phantom_server.phantom_server == 1 && var.gcp.use_static_ip== "1") ? 1 : 0
  name   = "phantom-ip-${count.index}"
  region = var.gcp.region                          # Region for IP allocation to align with instance location
}