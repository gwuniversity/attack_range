variable "elb_security_group_id" {
  description = "The security group id to use for the load balancer"
  type        = string
}

variable "apache-httpd_instance_id" {
  description = "The instance id of the heavy forwarder"
  type        = string
}

variable "aws" {}
variable "general" {}
variable "httpd_server" {}
variable "tags" {}
