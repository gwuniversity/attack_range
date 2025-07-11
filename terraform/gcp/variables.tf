
# -----------------------------------------------------------------------------
# Variable Definitions for Terraform Attack Range Deployment
# -----------------------------------------------------------------------------
# This file contains variable definitions used to deploy resources on Google Cloud
# Platform (GCP) for an attack range environment, including general configurations,
# instance-specific settings, and networking details. Each variable block defines
# default values and expected data types, allowing for flexibility and reusability
# across environments.
# -----------------------------------------------------------------------------

# General configuration settings for the attack range, including common parameters
variable "general" {
  description = "General configuration for the attack range"
  type = map(string)

  default = {
    attack_range_password               = "Pl3ase-k1Ll-me:p"  # Password for the attack range instances
    attack_range_name                   = "attack-range-name" # Name identifier for the attack range
    key_name                            = "attack-range-key-pair" # SSH key pair name
    ip_whitelist                        = "0.0.0.0/0" # Whitelist IP range for open access
    cloud_provider                      = "gcp" # Cloud provider, e.g., "gcp" or "aws"
    install_contentctl                  = "0" # "1" to install content control tools, "0" to skip
    carbon_black_cloud                  = "0" # "0" to disable Carrbon Black Cloud
    cisco_secure_endpoint               = "0" # "0" to disable Cisco Secure Endpoint
    crowdstrike_falcon                  = "0" # Install Crowdstrike Falcon Sensor
    crowdstrike_customer_ID             = "" # Crowdstrike Customer ID
    crowdstrike_logs_access_key_id      = "" # AWS Access Key ID for accessing CrowdStrike FDR logs from S3 (required for integration). Investigate if there is similar implementation in GCP.
    crowdstrike_logs_region             = "" # AWS region where the CrowdStrike FDR S3 bucket is hosted (e.g., "us-east-1"). Investigate if there is similar implementation in GCP.
    crowdstrike_logs_secret_access_key  = "" # AWS Secret Access Key for accessing CrowdStrike FDR logs from S3 (required for authentication). Investigate if there is similar implementation in GCP.
    crowdstrike_logs_sqs_url            = "" # AWS SQS URL to retrieve notifications about new CrowdStrike FDR logs in the S3 bucket. Investigate if there is similar implementation in GCP.
  }
}

# Google Cloud Platform-specific configuration settings
variable "gcp" {
  description = "GCP configuration"
  type = map(string)

  default = {
    region                  = "europe-west3" # GCP region
    zone                    = "europe-west3-a" # GCP zone within the specified region
    project_id              = "strange-mariner-455612-g2" # Replace with actual project ID
    public_key_path         = "~/.ssh/id_rsa.pub" # Path to SSH public key
    private_key_path        = "~/.ssh/id_rsa" # Path to SSH private key
    use_static_ip           = "0" # "1" to use elastic IPs, "0" otherwise
  }
}

# Network CIDR blocks for public and private subnets
variable "cidrs" {
  description = "Network configuration"
  type = map(any)

  default = {
    cidr_blocks = [
      "10.0.1.0/24", # Public subnet CIDR block
    ]
  }
}

# Splunk server instance configuration settings
variable "splunk_server" {
  description = "Configuration for the Splunk server instance"
  type = object({
    install_es              = string # "1" to install Splunk Enterprise Security, "0" otherwise
    byo_splunk              = string # "1" for BYO Splunk, "0" otherwise
    byo_splunk_ip           = string # BYO Splunk IP, if applicable
    ingest_bots3_data       = string # "1" to Ingest BOTS data to Attack Range
    install_dltk            = string # "1" to install Deep Learning Toolkit
    splunk_es_app           = string # Splunk Enterprise Security app to install
    splunk_url              = string # Splunk installation URL
    splunk_uf_url           = string # Splunk Universal Forwarder URL for Linux
    splunk_uf_win_url       = string # Splunk Universal Forwarder URL for Windows
    s3_bucket_url           = string # URL for S3 bucket containing Splunk apps
    splunk_apps             = string # Comma-separated list of Splunk apps to install
  })

  default = {
    install_es              = "0"
    byo_splunk              = "0"
    byo_splunk_ip           = "192.168.20.220"
    ingest_bots3_data       = "0"
    install_dltk            = "0"
    splunk_es_app           = "splunk-enterprise-security_710.spl"
    splunk_url              = "https://download.splunk.com/products/splunk/releases/9.3.0/linux/splunk-9.3.0-51ccf43db5bd-Linux-x86_64.tgz"
    splunk_uf_url           = "https://download.splunk.com/products/universalforwarder/releases/9.3.0/linux/splunkforwarder-9.3.0-51ccf43db5bd-linux-2.6-amd64.deb"
    splunk_uf_win_url       = "https://download.splunk.com/products/universalforwarder/releases/9.3.0/windows/splunkforwarder-9.3.0-51ccf43db5bd-x64-release.msi"
    s3_bucket_url           = "https://attack-range-appbinaries.s3-us-west-2.amazonaws.com"
    splunk_apps             = "TA-aurora-0.2.0.tar.gz,TA-osquery.tar.gz,app-for-circleci_011.tgz"
  }
}

# Configuration for Phantom server instance
variable "phantom_server" {
  description = "Phantom server configuration"
  type = object({
    phantom_server          = number # "1" if enabled, "0" otherwise
    phantom_app             = string # Name of the Phantom application to install
    phantom_byo             = string # 1 to enable Bring Your Own Phantom
  })

  default = {
    phantom_server          = "0"
    phantom_app             = "splunk_soar-unpriv-6.3.0.719-d9df3cc1-el8-x86_64.tgz"
    phantom_byo              = "0"
  }
}

# Configuration for NGINX server instance
variable "nginx_server" {
  type = map(string)
}

# Configuration for Kali Linux server instance
variable "kali_server" {
  description = "Kali Linux server configuration"
  type = object({
    kali_server             = number # "1" if enabled, "0" otherwise
  })

  default = {
    kali_server             = "0"
  }
}

# List of Linux server instance configurations
variable "linux_servers" {
  description = "List of configurations for each Linux server instance"
  type = list

  default = [
    {
      splunk_uf_url                 = "https://download.splunk.com/products/universalforwarder/releases/9.3.0/linux/splunkforwarder-9.3.0-51ccf43db5bd-linux-2.6-amd64.deb"
      sysmon_config                 = "SwiftOnSecurity.xml"
      install_crowdstrike           = "0"
      crowdstrike_linux_agent       = "falcon-sensor_7.17.0-17011_amd64.deb"
      install_cisco_secure_endpoint = "0"
    }
  ]
}

# Configuration for Windows servers
variable "windows_servers" {
  description = "Configuration for Windows servers"
  type = list

  default = [
    {
      advanced_logging              = "0"
      aurora_agent                  = "0"
      bad_blood                     = "0"
      create_domain                 = "0"
      crowdstrike_windows_agent     = "FalconSensor_Windows.7.19.exe"
      hostname                      = "ar-win"
      image                         = "windows-server-2019-dc*"
      install_carbon_black          = "0"
      install_cisco_secure_endpoint = "0"
      install_crowdstrike           = "0"
      install_red_team_tools        = "0"
      install_caldera_agent         = "0"
      join_domain                   = "0"
      win_sysmon_config             = "SwiftOnSecurity.xml"
    }
  ]
}

# Placeholder variables for Snort and Zeek servers and simulation settings
variable "snort_server" { 
  description = ""
  type = map(string)

  default = {
      snort_server            = "1"
  }
}

variable "zeek_server" { 
  description = ""
  type = map(string)

  default = {
      zeek_server             = "1"
    }
}

variable "simulation" { }

variable "caldera_server" {
    type = map(string)

    default = {
        "caldera_server" = "0"
    }
}