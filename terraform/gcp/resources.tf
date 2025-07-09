
# Load network module to set up the VPC network and associated resources.
module "networkModule" {
  source  = "./modules/network"
  general = var.general                   # General project variables
  gcp     = var.gcp                       # GCP-specific project settings
  cidrs   = var.cidrs                     # CIDR blocks for network subnets
}

# IAM module to create and manage service accounts with appropriate roles.
# module "iam" {
#   source            = "./modules/iam"
#   general           = var.general           # General project variables
#   gcp               = var.gcp               # GCP-specific settings
#   service_accounts  = var.service_accounts  # Map of service accounts and roles
# }
# Splunk Server module to deploy and configure Splunk server on GCP.
module "splunk_server" {
  source            = "./modules/splunk-server"
  vpc_network       = module.networkModule.vpc_network_id
  subnetwork        = module.networkModule.vpc_public_subnet_id

  # General configuration
  gcp               = var.gcp               # GCP-specific settings
  general           = var.general           # General project variables

  # Server instances and dependencies
  splunk_server     = var.splunk_server   # Splunk server configuration
  phantom_server    = var.phantom_server  # Phantom server configuration
  kali_server       = var.kali_server     # Kali server configuration
  snort_server      = var.snort_server    # Snort server configuration
  zeek_server       = var.zeek_server     # Zeek server configuration
  windows_servers   = var.windows_servers # Windows server configuration
  linux_servers     = var.linux_servers   # Linux server configuration
  simulation        = var.simulation      # Simulation configuration
}

# Phantom Server module to deploy Phantom server and configure network/security settings.
# module "phantom_server" {
#   source               = "./modules/phantom-server"

#   # Network configuration (GCP equivalent of VPC and subnet IDs)
#   vpc_network          = module.networkModule.vpc_network_id
#   subnetwork           = module.networkModule.vpc_public_subnet_id

#   # General configuration
#   general              = var.general
#   gcp                  = var.gcp
#   # service_accounts     = var.service_accounts
#   # phantom_sa_email     = module.iam.service_account_emails["phantom"]
#   # phantom_sa_roles     = module.iam.assigned_roles["phantom"]

#   # Server instances and dependencies
#   splunk_server        = var.splunk_server  # Splunk server configuration
#   phantom_server       = var.phantom_server # Phantom server configuration
# }

# NGINX Server module to deploy and manage an NGINX server.
module "nginx_server" {
  source               = "./modules/nginx-server"

  # Network configuration (GCP equivalent of VPC and subnet IDs)
  vpc_network          = module.networkModule.vpc_network_id
  subnetwork           = module.networkModule.vpc_public_subnet_id

  # General configuration
  general              = var.general
  gcp                  = var.gcp
  # service_accounts     = var.service_accounts
  # nginx_sa_email       = module.iam.service_account_emails["nginx"]
  # nginx_sa_roles       = module.iam.assigned_roles["nginx"]

  # Server instances and dependencies
  splunk_server        = var.splunk_server  # Splunk server configuration
  nginx_server         = var.nginx_server   # NGINX server configuration
}

# Kali Server module to deploy Kali Linux for security assessments and network tests.
# module "kali_server" {
#   source              = "./modules/kali-server"                   # Module source path

#   # Network configuration (GCP equivalent of VPC and subnet IDs)
#   vpc_network         = module.networkModule.vpc_network_id       # VPC network ID
#   subnetwork          = module.networkModule.vpc_public_subnet_id # Subnetwork ID                               # CIDR blocks for network subnets

#   # General configuration
#   general             = var.general                               # General project variables
#   gcp                 = var.gcp                                   # GCP-specific project settings
#   # service_accounts    = var.service_accounts                      # Map of service accounts and roles
#   # kali_sa_email       = module.iam.service_account_emails["kali"] # Kali service account email
#   # kali_sa_roles       = module.iam.assigned_roles["kali"]         # Kali service account roles

#   # Server instances and dependencies
#   kali_server         = var.kali_server                           # Kali server configuration
# }

# # Linux Server module to deploy and configure Linux servers.
module "linux_server" {
  source                = "./modules/linux-server"

  # Network configuration (GCP equivalent of VPC and subnet IDs)
  vpc_network           = module.networkModule.vpc_network_id
  subnetwork            = module.networkModule.vpc_public_subnet_id

  # General configuration
  general               = var.general
  gcp                   = var.gcp
  # service_accounts      = var.service_accounts
  # linux_sa_email        = module.iam.service_account_emails["linux"]
  # linux_sa_roles        = module.iam.assigned_roles["linux"]

  # Server instances and dependencies
  splunk_server         = var.splunk_server
  snort_server          = var.snort_server
  zeek_server           = var.zeek_server
  linux_servers         = var.linux_servers

  simulation            = var.simulation
  caldera_server        = var.caldera_server
}

# Windows Server module to deploy and configure Windows servers.
module "windows_server" {
  source                  = "./modules/windows-server"

  # Network configuration (GCP equivalent of VPC and subnet IDs)
  vpc_network             = module.networkModule.vpc_network_id
  subnetwork              = module.networkModule.vpc_public_subnet_id

  # General configuration
  general                 = var.general
  gcp                     = var.gcp

  # Server instances and dependencies
  splunk_server           = var.splunk_server
  snort_server            = var.snort_server
  zeek_server             = var.zeek_server
  windows_servers         = var.windows_servers

  simulation              = var.simulation
  caldera_server          = var.caldera_server
}

# Snort Server module to deploy a Snort instance for network intrusion detection.
module "snort_server" {
  source = "./modules/snort-server"

  # Network configuration (GCP equivalent of VPC and subnet IDs)
  vpc_network          = module.networkModule.vpc_network_id
  subnetwork           = module.networkModule.vpc_public_subnet_id

  # General configuration
  general              = var.general
  gcp                  = var.gcp
  # service_accounts     = var.service_accounts
  # snort_sa_email       = module.iam.service_account_emails["snort"]
  # snort_sa_roles       = module.iam.assigned_roles["snort"]

  # Server instances and dependencies
  splunk_server            = var.splunk_server
  snort_server             = var.snort_server
  windows_servers          = var.windows_servers
  windows_server_instances = module.windows_server.windows_servers
  linux_servers            = var.linux_servers
  linux_server_instances   = module.linux_server.linux_servers
}

# Zeek Server module to deploy and configure Zeek for network monitoring.
module "zeek_server" {
  source                          = "./modules/zeek-server"

  # Network configuration (GCP equivalent of VPC and subnet IDs)
  vpc_network                     = module.networkModule.vpc_network_id
  subnetwork                      = module.networkModule.vpc_public_subnet_id

  # General configuration
  general                         = var.general
  gcp                             = var.gcp
  # service_accounts                = var.service_accounts
  # zeek_sa_email                   = module.iam.service_account_emails["zeek"]
  # zeek_sa_roles                   = module.iam.assigned_roles["zeek"]

  # Server instances and dependencies
  splunk_server                   = var.splunk_server
  snort_server                    = var.snort_server
  zeek_server                     = var.zeek_server
  windows_servers                 = var.windows_servers
  windows_server_instances        = module.windows_server.windows_servers
  linux_servers                   = var.linux_servers
  linux_server_instances          = module.linux_server.linux_servers

  # snort_sensor_self_links         = module.snort_server.snort_server_self_links         # Snort sensor self-links
  # snort_forwarding_rule_self_link = module.snort_server.snort_forwarding_rule_self_link # Snort forwarding rule self-link
  # snort_backend_service_self_link = module.snort_server.snort_backend_service_self_link # Snort backend service self-link

}

# # Logging module for Splunk with configurations for alerts and monitoring.
# module "logging_splunk" {
#   source                  = "./modules/logging"
#   count                   = var.splunk_server.splunk_server == 1 ? 1 : 0
#   general                 = var.general
#   gcp                     = var.gcp
#   log_sink_name           = "splunk"
#   log_topic               = var.log_sink_config.topics["splunk"]
#   metric                  = var.log_sink_config.filters["splunk"]
#   monitor_alert           = var.monitor_alert
#   service_account_email   = module.iam.service_account_emails["splunk"]

#   destination_sink                = var.splunk_server.splunk_server == 1 ? replace(var.log_sink_config.destinations["splunk"], "GOOGLE_PROJECT_ID", var.gcp.project_id) : null
#   filter_sink                     = var.splunk_server.splunk_server == 1 ? replace(var.log_sink_config.filters["splunk"], "SPLUNK_INSTANCE_ID", module.splunk_server.splunk_instance_id[0]) : null
#   cpu_utilization_filter          = var.splunk_server.splunk_server == 1 ? replace(var.monitor_alert.telemetry.splunk.cpu_utilization, "SPLUNK_INSTANCE_ID", module.splunk_server.splunk_instance_id[0]) : null
#   disk_average_io_latency_filter  = var.splunk_server.splunk_server == 1 ? replace(var.monitor_alert.telemetry.splunk.disk_average_io_latency, "SPLUNK_INSTANCE_ID", module.splunk_server.splunk_instance_id[0]) : null
#   memory_balloon_ram_used_filter  = var.splunk_server.splunk_server == 1 ? replace(var.monitor_alert.telemetry.splunk.memory_balloon_ram_used, "SPLUNK_INSTANCE_ID", module.splunk_server.splunk_instance_id[0]) : null

#   writer_identity           = var.log_sink_config.writer_identity
#   notification_email        = var.monitor_alert.email_address
# }

# # Logging module for Phantom with configurations for alerts and monitoring
# module "logging_phantom" {
#   source                  = "./modules/logging"
#   count                   = var.phantom_server.phantom_server == 1 ? 1 : 0
#   general                 = var.general
#   gcp                     = var.gcp
#   log_sink_name           = "phantom"
#   log_topic               = var.log_sink_config.topics["phantom"]
#   metric                  = var.log_sink_config.filters["phantom"]
#   monitor_alert           = var.monitor_alert
#   service_account_email   = module.iam.service_account_emails["phantom"]

#   destination_sink                = var.phantom_server.phantom_server == 1 ? replace(var.log_sink_config.destinations["phantom"], "GOOGLE_PROJECT_ID", var.gcp.project_id) : null
#   filter_sink                     = var.phantom_server.phantom_server == 1 ? replace(var.log_sink_config.filters["phantom"], "PHANTOM_INSTANCE_ID", module.phantom_server.phantom_instance_id[0]) : null
#   cpu_utilization_filter          = var.phantom_server.phantom_server == 1 ? replace(var.monitor_alert.telemetry.phantom.cpu_utilization, "PHANTOM_INSTANCE_ID", module.phantom_server.phantom_instance_id[0]) : null
#   disk_average_io_latency_filter  = var.phantom_server.phantom_server == 1 ? replace(var.monitor_alert.telemetry.phantom.disk_average_io_latency, "PHANTOM_INSTANCE_ID", module.phantom_server.phantom_instance_id[0]) : null
#   memory_balloon_ram_used_filter  = var.phantom_server.phantom_server == 1 ? replace(var.monitor_alert.telemetry.phantom.memory_balloon_ram_used, "PHANTOM_INSTANCE_ID", module.phantom_server.phantom_instance_id[0]) : null

#   writer_identity           = var.log_sink_config.writer_identity
#   notification_email        = var.monitor_alert.email_address
# }

# # Logging module for NGINX with configurations for alerts and monitoring.
# module "logging_nginx" {
#   source                  = "./modules/logging"
#   count                   = var.nginx_server.nginx_server == 1 ? 1 : 0
#   general                 = var.general
#   gcp                     = var.gcp
#   log_sink_name           = "nginx"
#   log_topic               = var.log_sink_config.topics["nginx"]
#   metric                  = var.log_sink_config.filters["nginx"]
#   monitor_alert           = var.monitor_alert
#   service_account_email   = module.iam.service_account_emails["nginx"]

#   destination_sink                = var.nginx_server.nginx_server == 1 ? replace(var.log_sink_config.destinations["nginx"], "GOOGLE_PROJECT_ID", var.gcp.project_id) : null
#   filter_sink                     = var.nginx_server.nginx_server == 1 ? replace(var.log_sink_config.filters["nginx"], "NGINX_INSTANCE_ID", module.nginx_server.nginx_instance_id[0]) : null
#   cpu_utilization_filter          = var.nginx_server.nginx_server == 1 ? replace(var.monitor_alert.telemetry.nginx.cpu_utilization, "NGINX_INSTANCE_ID", module.nginx_server.nginx_instance_id[0]) : null
#   disk_average_io_latency_filter  = var.nginx_server.nginx_server == 1 ? replace(var.monitor_alert.telemetry.nginx.disk_average_io_latency, "NGINX_INSTANCE_ID", module.nginx_server.nginx_instance_id[0]) : null
#   memory_balloon_ram_used_filter  = var.nginx_server.nginx_server == 1 ? replace(var.monitor_alert.telemetry.nginx.memory_balloon_ram_used, "NGINX_INSTANCE_ID", module.nginx_server.nginx_instance_id[0]) : null

#   writer_identity           = var.log_sink_config.writer_identity
#   notification_email        = var.monitor_alert.email_address
# }

# # Logging module for Kali with configurations for alerts and monitoring.
# module "logging_kali" {
#   source                  = "./modules/logging"
#   count                   = var.kali_server.kali_server == 1 ? 1 : 0
#   general                 = var.general
#   gcp                     = var.gcp
#   log_sink_name           = "kali"
#   log_topic               = var.log_sink_config.topics["kali"]
#   metric                  = var.log_sink_config.filters["kali"]
#   monitor_alert           = var.monitor_alert
#   service_account_email   = module.iam.service_account_emails["kali"]

#   destination_sink                = var.kali_server.kali_server == 1 ? replace(var.log_sink_config.destinations["kali"], "GOOGLE_PROJECT_ID", var.gcp.project_id) : null
#   filter_sink                     = var.kali_server.kali_server == 1 ? replace(var.log_sink_config.filters["kali"], "KALI_INSTANCE_ID", module.kali_server.kali_instance_id[0]) : null
#   cpu_utilization_filter          = var.kali_server.kali_server == 1 ? replace(var.monitor_alert.telemetry.kali.cpu_utilization, "KALI_INSTANCE_ID", module.kali_server.kali_instance_id[0]) : null
#   disk_average_io_latency_filter  = var.kali_server.kali_server == 1 ? replace(var.monitor_alert.telemetry.kali.disk_average_io_latency, "KALI_INSTANCE_ID", module.kali_server.kali_instance_id[0]) : null
#   memory_balloon_ram_used_filter  = var.kali_server.kali_server == 1 ? replace(var.monitor_alert.telemetry.kali.memory_balloon_ram_used, "KALI_INSTANCE_ID", module.kali_server.kali_instance_id[0]) : null

#   writer_identity           = var.log_sink_config.writer_identity
#   notification_email        = var.monitor_alert.email_address
# }

# # Logging module for Linux with configurations for alerts and monitoring.
# module "logging_linux" {
#   source                  = "./modules/logging"

#   for_each = {
#     for idx, id in module.linux_server.linux_server_instance_ids :
#     format("instance_id_%d", idx) => id
#   }

#   general                 = var.general
#   gcp                     = var.gcp
#   log_sink_name           = format("linux-%d", local.linux_instance_id_to_index[each.value])
#   log_topic               = format(
#                               "%s-%d",
#                               var.log_sink_config.topics["linux"],                    # Static topic prefix
#                               lookup(local.linux_instance_id_to_index, each.value, 0) # Default to 0 if key not found
#                             )
#   metric                  = var.log_sink_config.filters["linux"]
#   monitor_alert           = var.monitor_alert
#   service_account_email   = module.iam.service_account_emails["linux"]

#   destination_sink                = replace(var.log_sink_config.destinations["linux"], "GOOGLE_PROJECT_ID", var.gcp.project_id)
#   filter_sink                     = replace(var.log_sink_config.filters["linux"], "LINUX_INSTANCE_ID", each.value)
#   cpu_utilization_filter          = replace(var.monitor_alert.telemetry.linux.cpu_utilization, "LINUX_INSTANCE_ID", each.value)
#   disk_average_io_latency_filter  = replace(var.monitor_alert.telemetry.linux.disk_average_io_latency, "LINUX_INSTANCE_ID", each.value)
#   memory_balloon_ram_used_filter  = replace(var.monitor_alert.telemetry.linux.memory_balloon_ram_used, "LINUX_INSTANCE_ID", each.value)

#   writer_identity           = var.log_sink_config.writer_identity
#   notification_email        = var.monitor_alert.email_address
# }

# # Logging module for Windows with configurations for alerts and monitoring.
# module "logging_windows" {
#   source                  = "./modules/logging"

#   for_each = {
#     for idx, id in module.windows_server.windows_server_instance_ids :
#     format("instance_id_%d", idx) => id
#   }

#   general                 = var.general
#   gcp                     = var.gcp
#   log_sink_name           = format("windows-%d", local.windows_instance_id_to_index[each.value])
#   log_topic               = format(
#                               "%s-%d",
#                               var.log_sink_config.topics["windows"],                    # Static topic prefix
#                               lookup(local.windows_instance_id_to_index, each.value, 0) # Default to 0 if key not found
#                             )
#   metric                  = var.log_sink_config.filters["windows"]
#   monitor_alert           = var.monitor_alert
#   service_account_email   = module.iam.service_account_emails["windows"]

#   destination_sink                = replace(var.log_sink_config.destinations["windows"], "GOOGLE_PROJECT_ID", var.gcp.project_id)
#   filter_sink                     = replace(var.log_sink_config.filters["windows"], "WINDOWS_INSTANCE_ID", each.value)
#   cpu_utilization_filter          = replace(var.monitor_alert.telemetry.windows.cpu_utilization, "WINDOWS_INSTANCE_ID", each.value)
#   disk_average_io_latency_filter  = replace(var.monitor_alert.telemetry.windows.disk_average_io_latency, "WINDOWS_INSTANCE_ID", each.value)
#   memory_balloon_ram_used_filter  = replace(var.monitor_alert.telemetry.windows.memory_balloon_ram_used, "WINDOWS_INSTANCE_ID", each.value)

#   writer_identity           = var.log_sink_config.writer_identity
#   notification_email        = var.monitor_alert.email_address
# }

# # Logging module for Snort with configurations for alerts and monitoring.
# module "logging_snort" {
#   source                  = "./modules/logging"
#   count                   = var.snort_server.snort_server == 1 ? 1 : 0
#   general                 = var.general
#   gcp                     = var.gcp
#   log_sink_name           = "snort"
#   log_topic               = var.log_sink_config.topics["snort"]
#   metric                  = var.log_sink_config.filters["snort"]
#   monitor_alert           = var.monitor_alert
#   service_account_email   = module.iam.service_account_emails["snort"]

#   destination_sink                = var.snort_server.snort_server == 1 ? replace(var.log_sink_config.destinations["snort"], "GOOGLE_PROJECT_ID", var.gcp.project_id) : null
#   filter_sink                     = var.snort_server.snort_server == 1 ? replace(var.log_sink_config.filters["snort"], "SNORT_INSTANCE_ID", module.snort_server.snort_instance_id[0]) : null
#   cpu_utilization_filter          = var.snort_server.snort_server == 1 ? replace(var.monitor_alert.telemetry.snort.cpu_utilization, "SNORT_INSTANCE_ID", module.snort_server.snort_instance_id[0]) : null
#   disk_average_io_latency_filter  = var.snort_server.snort_server == 1 ? replace(var.monitor_alert.telemetry.snort.disk_average_io_latency, "SNORT_INSTANCE_ID", module.snort_server.snort_instance_id[0]) : null
#   memory_balloon_ram_used_filter  = var.snort_server.snort_server == 1 ? replace(var.monitor_alert.telemetry.snort.memory_balloon_ram_used, "SNORT_INSTANCE_ID", module.snort_server.snort_instance_id[0]) : null

#   writer_identity           = var.log_sink_config.writer_identity
#   notification_email        = var.monitor_alert.email_address
# }

# # Logging module for Zeek with configurations for alerts and monitoring.
# module "logging_zeek" {
#   source                  = "./modules/logging"
#   count                   = var.zeek_server.zeek_server == 1 ? 1 : 0
#   general                 = var.general
#   gcp                     = var.gcp
#   log_sink_name           = "zeek"
#   log_topic               = var.log_sink_config.topics["zeek"]
#   metric                  = var.log_sink_config.filters["zeek"]
#   monitor_alert           = var.monitor_alert
#   service_account_email   = module.iam.service_account_emails["zeek"]

#   destination_sink                = var.zeek_server.zeek_server == 1 ? replace(var.log_sink_config.destinations["zeek"], "GOOGLE_PROJECT_ID", var.gcp.project_id) : null
#   filter_sink                     = var.zeek_server.zeek_server == 1 ? replace(var.log_sink_config.filters["zeek"], "ZEEK_INSTANCE_ID", module.zeek_server.zeek_instance_id[0]) : null
#   cpu_utilization_filter          = var.zeek_server.zeek_server == 1 ? replace(var.monitor_alert.telemetry.zeek.cpu_utilization, "ZEEK_INSTANCE_ID", module.zeek_server.zeek_instance_id[0]) : null
#   disk_average_io_latency_filter  = var.zeek_server.zeek_server == 1 ? replace(var.monitor_alert.telemetry.zeek.disk_average_io_latency, "ZEEK_INSTANCE_ID", module.zeek_server.zeek_instance_id[0]) : null
#   memory_balloon_ram_used_filter  = var.zeek_server.zeek_server == 1 ? replace(var.monitor_alert.telemetry.zeek.memory_balloon_ram_used, "ZEEK_INSTANCE_ID", module.zeek_server.zeek_instance_id[0]) : null

#   writer_identity           = var.log_sink_config.writer_identity
#   notification_email        = var.monitor_alert.email_address
# }

# # Logging module for IAM with configurations for alerts and monitoring.
# module "logging_iam" {
#   source                  = "./modules/logging"
#   general                 = var.general
#   gcp                     = var.gcp
#   log_sink_name           = "iam"
#   log_topic               = var.log_sink_config.topics["iam"]
#   metric                  = var.log_sink_config.filters["iam"]
#   monitor_alert           = var.monitor_alert
#   service_account_email   = module.iam.service_account_emails["iam"]

#   destination_sink        = replace(var.log_sink_config.destinations["iam"], "GOOGLE_PROJECT_ID", var.gcp.project_id)
#   filter_sink             = var.log_sink_config.filters["iam"]

#   writer_identity         = var.log_sink_config.writer_identity
#   notification_email      = var.monitor_alert.email_address
# }

# # Logging module for Network with configurations for alerts and monitoring
# module "logging_network" {
#   source                  = "./modules/logging"
#   general                 = var.general
#   gcp                     = var.gcp
#   log_sink_name           = "network"
#   log_topic               = var.log_sink_config.topics["network"]
#   metric                  = var.log_sink_config.filters["network"]
#   monitor_alert           = var.monitor_alert
#   service_account_email   = module.iam.service_account_emails["network"]

#   destination_sink        = replace(var.log_sink_config.destinations["network"], "GOOGLE_PROJECT_ID", var.gcp.project_id)
#   filter_sink             = var.log_sink_config.filters["network"]

#   writer_identity         = var.log_sink_config.writer_identity
#   notification_email      = var.monitor_alert.email_address
# }
