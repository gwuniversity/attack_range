output "sg_vpc_id" {
  value = [aws_security_group.default.id, aws_security_group.allow_list.id]
}

output "vpc_id" {
  value = local.vpc_id
}

output "ec2_subnet_id" {
  value = local.use_existing_vpc ? var.aws.private_subnet_1 : module.vpc[0].public_subnets[0]
}
