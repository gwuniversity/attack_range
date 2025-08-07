
variable "nlb_security_group_id" {
  description = "The security group id to use for the load balancer"
  type        = string
}

variable "edge-processor_instance_id" {}

variable "aws" {}
variable "edge_processor" {}
variable "general" {}
variable "tags" {}
