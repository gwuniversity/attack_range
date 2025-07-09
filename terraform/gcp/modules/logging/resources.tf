
# Resource: Pub/Sub Topic for Log Routing
# -----------------------------------------------------------------------------
# Creates a Pub/Sub topic as a destination for logs from the logging sink.
# Log entries are published to this topic, enabling downstream applications
# to subscribe and process these logs in real-time or in batches.
# -----------------------------------------------------------------------------
# Create Pub/Sub topic only if it doesn't exist
resource "google_pubsub_topic" "log_topic" {
  count   = try(var.log_topic != null, false) ? 1 : 0

  name    = var.log_topic               # Use topic name from the map as the topic name
  project = var.gcp.project_id          # GCP Project ID

  lifecycle {
    # prevent_destroy = false              # Prevent accidental topic deletion
    ignore_changes  = [name]            # Prevent Terraform from recreating existing topics
  }
}

# -----------------------------------------------------------------------------
# Resource: Logging Project Sink
# -----------------------------------------------------------------------------
# Configures a logging sink to capture and route log entries from the specified 
# Google Cloud project to the desired destination. This sink filters log entries 
# based on predefined criteria and routes them to a configured destination, such
# as a Pub/Sub topic, for further analysis or external processing.
# -----------------------------------------------------------------------------
# Create logging sink only if it doesn't exist
resource "google_logging_project_sink" "log_sink" {
  count = var.destination_sink != null && var.filter_sink != null ? 1 : 0

  name                    = "${var.log_sink_name}-log-sink"
  project                 = var.gcp.project_id

  destination             = var.destination_sink

  filter                  = var.filter_sink
  unique_writer_identity  = var.writer_identity

  lifecycle {
    # prevent_destroy = false                               # Prevent accidental sink deletion
    ignore_changes = [
      filter,                                            # Ignore changes to the filter
      destination,                                       # Ignore changes to the destination
    ]
  }
}

# ----------------------------------------------------------------------------
# Resource: Metric Descriptors
# ----------------------------------------------------------------------------
# Ensure the necessary metric descriptors exist before using them in alert policies
# Create log metric only if it doesn't exist
resource "google_logging_metric" "metric" {
  name        = var.log_sink_name
  description = "Custom metric for ${var.log_sink_name}"
  filter      = var.metric
  project     = var.gcp.project_id

  metric_descriptor {
    metric_kind = "DELTA"   # Use DELTA for counting occurrences
    value_type  = "INT64"   # INT64 for counting

    labels {
      key         = "instance_id"
      value_type  = "STRING"
      description = "Instance ID where the metric is logged"
    }
  }

  label_extractors = {
    "instance_id" = "EXTRACT(resource.labels.instance_id)"
  }
}

# -----------------------------------------------------------------------------
# Resource: CPU Utilization Alert Policy
# -----------------------------------------------------------------------------
# Configures an alert policy to monitor high CPU utilization within specified 
# instances. This policy triggers notifications if the CPU utilization exceeds 
# the set threshold for a defined duration, helping to detect performance issues 
# or unexpected usage spikes in resources.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Resource: Disk Utilization Alert Policy
# -----------------------------------------------------------------------------
# Configures an alert policy for high disk utilization across specified instances.
# This policy monitors disk usage and sends notifications when utilization exceeds 
# the defined threshold, providing insight into potential storage issues or overuse.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Resource: Memory Utilization Alert Policy
# -----------------------------------------------------------------------------
# Configures an alert policy for high memory utilization within specified instances.
# This policy tracks memory usage and triggers alerts when utilization exceeds 
# the specified threshold, supporting proactive identification of memory constraints.
# -----------------------------------------------------------------------------

# Alert Policy: Create dynamically for CPU, Disk, and Memory utilization
resource "google_monitoring_alert_policy" "utilization_alert" {
  for_each = {
    for k, v in {
      "cpu"    = var.cpu_utilization_filter
      "disk"   = var.disk_average_io_latency_filter
      "memory" = var.memory_balloon_ram_used_filter
    } : k => v if v != null
  }

  display_name = "High ${upper(each.key)} Utilization Alert - ${var.log_sink_name}"
  documentation {
    content = "The $${upper(each.key)} of the $${resource.type} $${resource.label.instance_id} in $${resource.project} has exceeded 80% for over 1 minute."
  }
  project      = var.gcp.project_id
  combiner     = "OR"

  conditions {
    display_name = "${upper(each.key)} Utilization Condition - ${var.log_sink_name}"
    condition_threshold {
      filter          = each.value
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "60s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
      }
    }
  }

  alert_strategy {
    notification_channel_strategy {
        renotify_interval = "1800s"
        notification_channel_names = [google_monitoring_notification_channel.email.id]
    }
  }

  # Reference the shared notification channel to avoid duplicates
  notification_channels = [google_monitoring_notification_channel.email.id]

  user_labels = {
    severity = "warning"
  }
}

# -----------------------------------------------------------------------------
# Resource: Email Notification Channel
# -----------------------------------------------------------------------------
# Sets up an email notification channel for alert policies, enabling email alerts 
# to be sent when monitored resources exceed specified thresholds. This resource 
# is reusable across multiple alert policies to streamline alert management.
# -----------------------------------------------------------------------------
resource "google_monitoring_notification_channel" "email" {
  display_name = "Email Notification Channel"                 # Display name for the notification channel
  project      = var.gcp.project_id                           # GCP Project ID
  type         = var.monitor_alert.notification               # Notification type (e.g., "email")
  labels = {
    email_address = var.monitor_alert.email_address           # Target email address for alerts
  }
}