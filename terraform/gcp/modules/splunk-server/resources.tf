# -----------------------------------------------------------------------------
# Splunk Server Configuration on Google Compute Platform
# This resource block defines a Splunk Server instance in GCP, including 
# networking, boot disk, metadata, and provisioners for configuration 
# and software installation.
# -----------------------------------------------------------------------------

# Splunk Server GCP Instance
resource "google_compute_instance" "splunk_server" {
    count        = (var.splunk_server.byo_splunk == "0") ? 1 : 0
    name         = "${var.general.attack_range_name}-splunk-server-${var.general.key_name}"
    machine_type = "e2-standard-4"
    zone         = var.gcp.zone

    # Assign the Splunk Service Account to this instance
    # service_account {
    #     email  = var.splunk_sa_email
    #     scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    # }

    # SSH Metadata Configuration
    metadata = {
        ssh-keys = "ubuntu:${file(var.gcp.public_key_path)}"  # Ensure the path points to your SSH public key file
    }

    # Boot Disk Configuration
    boot_disk {
        initialize_params {
            image = "ubuntu-2204-lts"            # OS image for the instance, e.g., Ubuntu
            size  = 120        # Disk size in GB
            type  = "pd-standard"        # Disk type, e.g., pd-ssd
        }
        auto_delete = true                             # Automatically delete disk on instance termination
    }

    # Network Interface Configuration
    network_interface {
        network     = var.vpc_network                  # VPC network name
        subnetwork  = var.subnetwork                   # Subnetwork name
        network_ip  = "10.0.1.12"    # Static internal IP (optional)
        access_config {                                # External IP configuration
            # nat_ip = google_compute_address.splunk_ip.address
            nat_ip = length(google_compute_address.splunk_ip) > count.index ? google_compute_address.splunk_ip[count.index].address : null
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

    # Tagging and Labeling for Organization
    tags = ["gcp-infrastructure", "splunk-server", "attack-range"]

    labels = {
        name = "ar-splunk-${var.general.key_name}-${var.general.attack_range_name}"
    }

    # -----------------------------------------------------------------------------
    # Provisioning Configuration
    # The provisioners below handle initial setup and apply configurations using
    # both remote-exec and local-exec to connect to and configure the instance.
    # -----------------------------------------------------------------------------

    # Remote-exec Provisioner for Initial Setup Validation
    provisioner "remote-exec" {
        inline = ["echo booted"]                       # Basic connectivity check

        connection {
            type        = "ssh"
            user        = "ubuntu"
            host        = self.network_interface[0].access_config[0].nat_ip
            private_key = file(var.gcp.private_key_path)
        }
    }

    # Local-exec Provisioner for Variable Setup for Ansible
    provisioner "local-exec" {
        working_dir = "../ansible"
        command = <<-EOT
            cat > vars/splunk_vars.json << 'EOF'
            {
                "ansible_python_interpreter": "/usr/bin/python3",
                "general": ${jsonencode(var.general)},
                "gcp": ${jsonencode(var.gcp)},
                "splunk_server": ${jsonencode(var.splunk_server)},
                "phantom_server": ${jsonencode(var.phantom_server)},
                "simulation": ${jsonencode(var.simulation)},
                "kali_server": ${jsonencode(var.kali_server)},
                "zeek_server": ${jsonencode(var.zeek_server)},
                "windows_servers": ${jsonencode(var.windows_servers)},
                "linux_servers": ${jsonencode(var.linux_servers)},
                "snort_server": ${jsonencode(var.snort_server)}
            }
            EOF
        EOT
    }

    # Local-exec Provisioner to Run Ansible Playbook for Splunk Server Setup
    provisioner "local-exec" {
        working_dir = "../ansible"
        command = <<-EOT
            ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu --private-key '${var.gcp.private_key_path}' -i '${self.network_interface[0].access_config[0].nat_ip},' splunk_server.yml -e "@vars/splunk_vars.json"
        EOT
    }
}

# -----------------------------------------------------------------------------
# External IP for Splunk Server
# Creates a static IP address to be assigned to the Splunk server instance.
# -----------------------------------------------------------------------------
resource "google_compute_address" "splunk_ip" {
    count  = (var.splunk_server.byo_splunk == "0" && var.gcp.use_static_ip == "1") ? 1 : 0
    name   = "splunk-ip-${var.general.key_name}-${count.index}"
    region = var.gcp.region
}
