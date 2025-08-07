
output "arn" {
  description = "The Amazon Resource Name (ARN) of the load balancer."
  value       = aws_lb.nlb[0].arn
}

output "dns_name" {
  description = "The DNS name of the load balancer."
  value       = aws_lb.nlb[0].dns_name
}

output "traffic_mirror_target_id" {
  description = "The traffic mirror target ID for the NLB"
  value       = var.aws.use_nlb == "1" ? aws_ec2_traffic_mirror_target.nlb_target[0].id : null
}

output "traffic_mirror_filter_id" {
  description = "The traffic mirror filter ID for the NLB"
  value       = var.aws.use_nlb == "1" ? aws_ec2_traffic_mirror_filter.nlb_filter[0].id : null
}
