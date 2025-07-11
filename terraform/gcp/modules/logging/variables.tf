
variable "general" { }

variable "gcp" { }

variable "log_sink_name" { }

variable "log_topic" { }

variable "metric" { }

variable "destination_sink" {
  type    = string
  default = null  # Default to empty string if not provided
}

variable "filter_sink" {
  type    = string
  default = null  # Default to empty string if not provided
}

variable "cpu_utilization_filter" {
  description = "Optional CPU utilization filter for monitoring"
  type        = string
  default     = null # Default to empty string if not provided
}

variable "disk_average_io_latency_filter" {
  description = "Optional DISK utilization filter for monitoring"
  type        = string
  default     = null # Default to empty string if not provided
}

variable "memory_balloon_ram_used_filter" {
  description = "Optional MEMORY utilization filter for monitoring"
  type        = string
  default     = null # Default to empty string if not provided
}

variable "monitor_alert" { }

variable writer_identity { }

variable "service_account_email" { }

variable "notification_email" { }
