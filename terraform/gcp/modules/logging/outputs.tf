
# Output: Log Sink Writer Identity
# -----------------------------------------------------------------------------
# This output provides the unique writer identity associated with the logging
# sink, which is necessary for setting permissions to write logs to this sink.
# The writer identity will have the necessary permissions to route logs to the
# configured destinations as specified in the project.
# -----------------------------------------------------------------------------
output "log_sink_writer_identity" {
  description = "The writer identity of the log sinks."
  value       = { for key, sink in google_logging_project_sink.log_sink : key => sink.writer_identity }
}

# -----------------------------------------------------------------------------
# Output: Pub/Sub Topic ID
# -----------------------------------------------------------------------------
# This output provides the identifier for the Pub/Sub topic configured to receive
# logs. The Pub/Sub topic ID is essential for log integration with downstream
# systems or external log processing services. Each log entry from the project
# is routed to this topic, enabling real-time or batch processing.
# -----------------------------------------------------------------------------
output "pubsub_topic_ids" {
  value       = { for key, topic in google_pubsub_topic.log_topic : key => topic.id }
  description = "Map of Pub/Sub topic IDs for each log destination."
}

#-----------------------------------------------
# Logging Metrics
#-----------------------------------------------
output "log_topic" {
  value = var.log_topic
}

output "monitor_alert" {
  value = var.monitor_alert
}

output "service_account_email" {
  value = var.service_account_email
}

output "destination_sink" {
  value = var.destination_sink
}

output "filter_sink" {
  value = var.filter_sink
}

output "cpu_utilization_filter" {
  value = var.cpu_utilization_filter
}

output "disk_average_io_latency_filter" {
  value = var.disk_average_io_latency_filter
}

output "memory_balloon_ram_used_filter" {
  value = var.memory_balloon_ram_used_filter
}

output "writer_identity" {
  value = var.writer_identity
}
