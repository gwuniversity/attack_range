locals {
  use_existing_vpc = var.aws.vpc_id != ""
}

data "aws_subnet" "private_subnet_1" {
  count = local.use_existing_vpc ? 1 : 0
  id    = var.aws.private_subnet_1
}

data "aws_subnet" "private_subnet_2" {
  count = local.use_existing_vpc ? 1 : 0
  id    = var.aws.private_subnet_2
}

# Create VPC if vpc_id is not supplied
module "vpc" {
  count  = local.use_existing_vpc ? 0 : 1
  source = "terraform-aws-modules/vpc/aws"

  name                 = "vpc_${var.general.key_name}_${var.general.attack_range_name}"
  cidr                 = "10.0.0.0/16"
  public_subnets       = [var.aws.network_cidr, var.aws.network_cidr_2]
  private_subnets      = [var.aws.private_network_cidr, var.aws.private_network_cidr_2]
  enable_dns_hostnames = true
}

# Use the public or private subnet CIDRs based on var.aws.use_public_ips
locals {
  ar_subnets = local.use_existing_vpc ? (
    [data.aws_subnet.private_subnet_1[0].cidr_block, data.aws_subnet.private_subnet_2[0].cidr_block]
    ) : (
    var.aws.use_public_ips == "1" ? module.vpc[0].public_subnets : module.vpc[0].private_subnets
  )
  vpc_id = local.use_existing_vpc ? var.aws.vpc_id : module.vpc[0].vpc_id
}

# Create AWS Security Groups
# Default security group for all subnets in the attack range
# Allows all traffic within the attack range
# Allows ICMP traffic within the attack range
# Allows all outbound traffic
resource "aws_security_group" "default" {
  name   = "sg_subnets_${var.general.key_name}_${var.general.attack_range_name}"
  vpc_id = local.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = local.ar_subnets
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = local.ar_subnets
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_list" {
  name   = "sg_vpn_${var.general.key_name}_${var.general.attack_range_name}"
  vpc_id = local.vpc_id

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = split(",", var.general.ip_allow_list)
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = split(",", var.general.ip_allow_list)
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = split(",", var.general.ip_allow_list)
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = split(",", var.general.ip_allow_list)
  }

  ingress {
    from_port   = 5986
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = split(",", var.general.ip_allow_list)
  }

  ingress {
    from_port   = 5985
    to_port     = 5985
    protocol    = "tcp"
    cidr_blocks = split(",", var.general.ip_allow_list)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
