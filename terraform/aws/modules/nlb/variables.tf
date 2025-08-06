
variable "nlb_security_group_id" {
  description = "The security group id to use for the load balancer"
  type        = string
}

variable "edge-processor_instance_id" {}
variable "zeek_network_interface_id" {}
variable "snort_network_interface_id" {}

variable "aws" {}
variable "edge_processor" {}
variable "zeek_server" {}
variable "snort_server" {}
variable "general" {}
variable "tags" {}
