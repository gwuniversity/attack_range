variable "nlb_security_group_id" {
  description = "The id of the security group for the load balancer if in use"
  type        = string
}

variable "aws" {}
variable "general" {}
variable "edge_processor" {}
variable "splunk_server" {}
variable "instance_profile_name" {}
variable "vpc_security_group_ids" {}
