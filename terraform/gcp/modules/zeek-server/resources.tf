# -----------------------------------------------------------------------------
# Zeek Sensor Instance Configuration
# -----------------------------------------------------------------------------
# This resource deploys a Zeek sensor instance in Google Cloud Platform (GCP),
# along with network settings, disk configurations, provisioners, and a packet
# mirroring setup to capture and forward network traffic to the instance.
# -----------------------------------------------------------------------------

# Zeek instance configuration in GCP
resource "google_compute_instance" "zeek_sensor" {
  count        = var.zeek_server.zeek_server == "1" ? 1 : 0
  name         = "${var.general.attack_range_name}-zeek-server-${var.general.key_name}"
  machine_type = "e2-standard-4"  # Instance type, similar to "m5.2xlarge" in AWS
  zone         = var.gcp.zone

  # Boot Disk configuration for Zeek instance
  boot_disk {
    initialize_params {
      image = "ubuntu-2004-lts"      # GCP image for instance, e.g., "ubuntu-2204-lts"
      size  = 60  # Disk size in GB
      type  = "pd-standard"  # Disk type, e.g., "pd-ssd"
    }
    auto_delete = true
  }

  # Network interface configuration with optional static IP
  network_interface {
    network    = var.vpc_network
    subnetwork = var.subnetwork
    network_ip = "10.0.1.50"  # Internal IP for instance
    access_config {
      nat_ip = length(google_compute_address.zeek_ip) > count.index ? google_compute_address.zeek_ip[count.index].address : null
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

  # Assign the Zeek Service Account to this instance
    # service_account {
    #     email  = var.zeek_sa_email
    #     scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    # }

  # SSH key metadata for access
  metadata = {
    ssh-keys = "ubuntu:${file(var.gcp.public_key_path)}"
  }

  # Tags and labels for organizational purposes
  tags = ["gcp-infrastructure", "zeek-server", "attack-range"]
  labels = {
    name = "ar-zeek-${var.general.key_name}-${var.general.attack_range_name}"
  }

  # Provisioner for initial remote setup verification
  provisioner "remote-exec" {
    inline = ["echo booted"]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = self.network_interface[0].access_config[0].nat_ip
      private_key = file(var.gcp.private_key_path)
    }
  }

  # Local provisioner to generate Ansible variable file for Zeek setup
  provisioner "local-exec" {
    working_dir = "../ansible"
    command = <<-EOT
      cat > vars/zeek_vars.json << 'EOF'
      {
        "ansible_python_interpreter": "/usr/bin/python3",
        "general": ${jsonencode(var.general)},
        "splunk_server": ${jsonencode(var.splunk_server)},
        "zeek_server": ${jsonencode(var.zeek_server)}
      }
      EOF
    EOT
  }

  # Local provisioner to execute Ansible playbook for Zeek configuration
  provisioner "local-exec" {
    working_dir = "../ansible"
    command = <<-EOT
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu --private-key '${var.gcp.private_key_path}' -i '${self.network_interface[0].access_config[0].nat_ip},' zeek_server.yml -e "@vars/zeek_vars.json"
    EOT
  }
}

# Static IP allocation for the Zeek instance
resource "google_compute_address" "zeek_ip" {
  count  = (var.zeek_server.zeek_server == "1" && var.gcp.use_static_ip == "1") ? 1 : 0
  name   = "zeek-ip-${count.index}"
  region = var.gcp.region
}

# Packet Mirroring configuration for traffic redirection to the Zeek instance
resource "google_compute_packet_mirroring" "zeek_packet_mirroring" {
  count     = var.zeek_server.zeek_server == "1" ? 1 : 0
  name      = "zeek-packet-mirroring-${var.general.key_name}-${var.general.attack_range_name}"
  region    = var.gcp.region
  
  network {
    url = var.vpc_network
  }

  mirrored_resources {
    instances {
        url = google_compute_instance.zeek_sensor[0].self_link  # Link to the instance to mirror traffic from
    }
  }

  # Packet filter settings for mirroring
  filter {
    direction = "BOTH"
    cidr_ranges = ["0.0.0.0/0"]
  }

  collector_ilb {
    url = google_compute_forwarding_rule.zeek_forwarding_rule[0].self_link  # Link to packet mirroring collector
  }
}

# Mirror sessions for Windows servers
resource "google_compute_packet_mirroring" "zeek_windows_mirroring" {
  count     = var.zeek_server.zeek_server == "1" ? length(var.windows_servers) : 0
  name      = "zeek-windows-mirroring-${count.index}-${var.general.key_name}-${var.general.attack_range_name}"
  region    = var.gcp.region
  
  network {
    url = var.vpc_network
  }

  mirrored_resources {
    instances {
      url = var.windows_server_instances[count.index].self_link
    }
  }

  filter {
    direction = "BOTH"
    cidr_ranges = ["0.0.0.0/0"]
  }

  collector_ilb {
    url = google_compute_forwarding_rule.zeek_forwarding_rule[0].self_link
  }
}

# Mirror sessions for Linux servers
resource "google_compute_packet_mirroring" "zeek_linux_mirroring" {
  count     = var.zeek_server.zeek_server == "1" ? length(var.linux_servers) : 0
  name      = "zeek-linux-mirroring-${count.index}-${var.general.key_name}-${var.general.attack_range_name}"
  region    = var.gcp.region
  
  network {
    url = var.vpc_network
  }

  mirrored_resources {
    instances {
      url = var.linux_server_instances[count.index].self_link
    }
  }

  filter {
    direction = "BOTH"
    cidr_ranges = ["0.0.0.0/0"]
  }

  collector_ilb {
    url = google_compute_forwarding_rule.zeek_forwarding_rule[0].self_link
  }
}

# Internal load balancer as packet mirroring collector for Zeek traffic
resource "google_compute_forwarding_rule" "zeek_forwarding_rule" {
  count     = var.zeek_server.zeek_server == "1" ? 1 : 0
  name                   = "zeek-mirror-forwarding-rule"
  region                 = var.gcp.region
  load_balancing_scheme  = "INTERNAL"
  backend_service        = google_compute_region_backend_service.zeek_backend_service[0].self_link
  all_ports              = true  # Open all ports for traffic
  ip_protocol            = "TCP"
  network                = var.vpc_network
  subnetwork             = var.subnetwork
  is_mirroring_collector = true
}

# Backend service for load balancing and packet collection for Zeek
resource "google_compute_region_backend_service" "zeek_backend_service" {
  count     = var.zeek_server.zeek_server == "1" ? 1 : 0
  name              = "zeek-backend-service"
  region            = var.gcp.region
  protocol          = "TCP"
  health_checks     = [google_compute_health_check.zeek_health_check[0].id]

  backend {
    group           = google_compute_instance_group.zeek_group[0].self_link
    balancing_mode  = "CONNECTION"
  }
}

# Instance group for the Zeek instances (used in backend service)
resource "google_compute_instance_group" "zeek_group" {
  count     = var.zeek_server.zeek_server == "1" ? 1 : 0
  name       = "zeek-instance-group"
  zone       = var.gcp.zone
  instances  = [for instance in google_compute_instance.zeek_sensor : instance.self_link]
  network    = var.vpc_network
}

# Health check for Zeek instances (for load balancing)
resource "google_compute_health_check" "zeek_health_check" {
  count     = var.zeek_server.zeek_server == "1" ? 1 : 0
  name               = "zeek-health-check"
  check_interval_sec = 10
  timeout_sec        = 5

  tcp_health_check {
    port = 80  # Port for health check; adjust to match the actual service port
  }
}
