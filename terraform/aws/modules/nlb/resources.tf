resource "aws_lb" "nlb" {
  count                                                        = var.edge_processor.use_nlb == "1" ? 1 : 0
  name                                                         = "ar-nlb-${var.general.attack_range_name}"
  internal                                                     = true # Set to true for internal/private NLB
  load_balancer_type                                           = "network"
  dns_record_client_routing_policy                             = "availability_zone_affinity"
  security_groups                                              = [var.nlb_security_group_id]
  subnets                                                      = [var.aws.private_subnet_1, var.aws.private_subnet_2]
  enable_deletion_protection                                   = false
  enable_cross_zone_load_balancing                             = true
  enforce_security_group_inbound_rules_on_private_link_traffic = "off"

  tags = merge({ Name = "ar-nlb-${var.general.key_name}-${var.general.attack_range_name}" },
    var.tags
  )
}

resource "aws_lb_target_group" "splunkd_tg" {
  count    = var.edge_processor.use_nlb == "1" ? 1 : 0
  port     = 9997
  protocol = "TCP"
  vpc_id   = var.aws.vpc_id

  tags = merge({ Name = "ar-nlb-${var.general.attack_range_name}" },
    var.tags
  )
}

resource "aws_lb_target_group_attachment" "edge_splunkd" {
  count            = var.edge_processor.use_nlb == "1" ? 1 : 0
  target_group_arn = aws_lb_target_group.splunkd_tg[count.index].arn
  target_id        = var.edge-processor_instance_id
}

resource "aws_lb_listener" "nlb_splunkd" {
  count             = var.edge_processor.use_nlb == "1" ? 1 : 0
  load_balancer_arn = aws_lb.nlb[count.index].arn
  port              = "9997"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.splunkd_tg[count.index].arn
  }
}

resource "aws_lb_target_group" "hec_tg" {
  count    = var.edge_processor.use_nlb == "1" ? 1 : 0
  port     = 8088
  protocol = "TCP"
  vpc_id   = var.aws.vpc_id

  tags = merge({ Name = "${var.general.key_name}_${var.general.attack_range_name}-hec-tg" },
    var.tags
  )
}

resource "aws_lb_target_group_attachment" "edge_hec" {
  count            = var.edge_processor.use_nlb == "1" ? 1 : 0
  target_group_arn = aws_lb_target_group.hec_tg[count.index].arn
  target_id        = var.edge-processor_instance_id
}

resource "aws_lb_listener" "nlb_hec" {
  count             = var.edge_processor.use_nlb == "1" ? 1 : 0
  load_balancer_arn = aws_lb.nlb[count.index].arn
  port              = "8088"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hec_tg[count.index].arn
  }
}

resource "aws_lb_target_group" "syslog_tg" {
  count    = var.edge_processor.use_nlb == "1" ? 1 : 0
  port     = 514
  protocol = "TCP"
  vpc_id   = var.aws.vpc_id

  tags = merge({ Name = "${var.general.key_name}_${var.general.attack_range_name}-syslog-tg" },
    var.tags
  )
}

resource "aws_lb_target_group_attachment" "edge_syslog" {
  count            = var.edge_processor.use_nlb == "1" ? 1 : 0
  target_group_arn = aws_lb_target_group.syslog_tg[count.index].arn
  target_id        = var.edge-processor_instance_id
}

resource "aws_lb_listener" "nlb_syslog" {
  count             = var.edge_processor.use_nlb == "1" ? 1 : 0
  load_balancer_arn = aws_lb.nlb[count.index].arn
  port              = "514"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.syslog_tg[count.index].arn
  }
}

resource "aws_lb_target_group" "vxlan_tg" {
  count    = var.edge_processor.use_nlb == "1" ? 1 : 0
  port     = 4789
  protocol = "UDP"
  vpc_id   = var.aws.vpc_id

  tags = merge({ Name = "${var.general.key_name}_${var.general.attack_range_name}-vxlan-tg" },
    var.tags
  )
}

resource "aws_lb_target_group_attachment" "edge_vxlan" {
  count            = var.edge_processor.use_nlb == "1" ? 1 : 0
  target_group_arn = aws_lb_target_group.vxlan_tg[count.index].arn
  target_id        = var.edge-processor_instance_id
}

resource "aws_lb_listener" "nlb_vxlan" {
  count             = var.edge_processor.use_nlb == "1" ? 1 : 0
  load_balancer_arn = aws_lb.nlb[count.index].arn
  port              = "4789"
  protocol          = "UDP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vxlan_tg[count.index].arn
  }
}

# Traffic mirror target for the NLB itself
resource "aws_ec2_traffic_mirror_target" "nlb_target" {
  count                     = var.edge_processor.use_nlb == "1" ? 1 : 0
  description               = "Traffic Mirror Target for NLB"
  network_load_balancer_arn = aws_lb.nlb[0].arn
}

# Traffic mirror filter for NLB
resource "aws_ec2_traffic_mirror_filter" "nlb_filter" {
  count       = var.edge_processor.use_nlb == "1" ? 1 : 0
  description = "Traffic Mirror Filter for NLB"
}

resource "aws_ec2_traffic_mirror_filter_rule" "nlb_ingress" {
  count                    = var.edge_processor.use_nlb == "1" ? 1 : 0
  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.nlb_filter[0].id
  destination_cidr_block   = "0.0.0.0/0"
  source_cidr_block        = "0.0.0.0/0"
  rule_number              = 1
  rule_action              = "accept"
  traffic_direction        = "ingress"
}

resource "aws_ec2_traffic_mirror_filter_rule" "nlb_egress" {
  count                    = var.edge_processor.use_nlb == "1" ? 1 : 0
  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.nlb_filter[0].id
  destination_cidr_block   = "0.0.0.0/0"
  source_cidr_block        = "0.0.0.0/0"
  rule_number              = 1
  rule_action              = "accept"
  traffic_direction        = "egress"
}
