resource "aws_lb" "nlb" {
  count                                                        = var.aws.use_nlb == "1" ? 1 : 0
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
  count    = var.aws.use_nlb == "1" ? 1 : 0
  port     = 9997
  protocol = "TCP"
  vpc_id   = var.aws.vpc_id

  tags = merge({ Name = "ar-nlb-${var.general.attack_range_name}" },
    var.tags
  )
}

resource "aws_lb_target_group_attachment" "edge_splunkd" {
  count            = var.aws.use_nlb == "1" ? 1 : 0
  target_group_arn = aws_lb_target_group.splunkd_tg[count.index].arn
  target_id        = var.edge-processor_instance_id
}

resource "aws_lb_listener" "nlb_splunkd" {
  count             = var.aws.use_nlb == "1" ? 1 : 0
  load_balancer_arn = aws_lb.nlb[count.index].arn
  port              = "9997"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.splunkd_tg[count.index].arn
  }
}

resource "aws_lb_target_group" "hec_tg" {
  count    = var.aws.use_nlb == "1" ? 1 : 0
  port     = 8088
  protocol = "TCP"
  vpc_id   = var.aws.vpc_id

  tags = merge({ Name = "${var.general.key_name}_${var.general.attack_range_name}-hec-tg" },
    var.tags
  )
}

resource "aws_lb_target_group_attachment" "edge_hec" {
  count            = var.aws.use_nlb == "1" ? 1 : 0
  target_group_arn = aws_lb_target_group.hec_tg[count.index].arn
  target_id        = var.edge-processor_instance_id
}

resource "aws_lb_listener" "nlb_hec" {
  count             = var.aws.use_nlb == "1" ? 1 : 0
  load_balancer_arn = aws_lb.nlb[count.index].arn
  port              = "8088"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hec_tg[count.index].arn
  }
}

resource "aws_lb_target_group" "syslog_tg" {
  count    = var.aws.use_nlb == "1" ? 1 : 0
  port     = 514
  protocol = "TCP"
  vpc_id   = var.aws.vpc_id

  tags = merge({ Name = "${var.general.key_name}_${var.general.attack_range_name}-syslog-tg" },
    var.tags
  )
}

resource "aws_lb_target_group_attachment" "edge_syslog" {
  count            = var.aws.use_nlb == "1" ? 1 : 0
  target_group_arn = aws_lb_target_group.syslog_tg[count.index].arn
  target_id        = var.edge-processor_instance_id
}

resource "aws_lb_listener" "nlb_syslog" {
  count             = var.aws.use_nlb == "1" ? 1 : 0
  load_balancer_arn = aws_lb.nlb[count.index].arn
  port              = "514"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.syslog_tg[count.index].arn
  }
}
