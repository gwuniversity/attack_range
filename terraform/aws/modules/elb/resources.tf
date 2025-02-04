data "aws_caller_identity" "current" {}

data "aws_acm_certificate" "cert" {
  domain = var.httpd_server.domain
}

data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket" "elb" {
  count         = var.httpd_server.elb_bucket == null ? 1 : 0
  bucket        = "${var.general.name_prefix}-${var.general.attack_range_name}-elb-access-${var.aws.region}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_policy" "elb_logs" {
  count  = var.httpd_server.elb_bucket == null ? 1 : 0
  bucket = aws_s3_bucket.elb[count.index].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.elb[count.index].arn}/*"
      }
    ]
  })
}

resource "aws_lb" "main_elb" {
  count = var.httpd_server.use_alb == "1" ? 1 : 0
  name  = "ar-elb-www-${var.general.attack_range_name}"

  internal                         = true
  enable_cross_zone_load_balancing = true
  idle_timeout                     = "60"
  load_balancer_type               = "application"

  security_groups            = [var.elb_security_group_id]
  subnets                    = [var.aws.public_subnet_1, var.aws.public_subnet_2]
  enable_deletion_protection = false

  access_logs {
    bucket  = var.httpd_server.elb_bucket == null ? aws_s3_bucket.elb[count.index].id : var.httpd_server.elb_bucket
    prefix  = "${data.aws_caller_identity.current.id}/ar-elb-www-${var.general.attack_range_name}"
    enabled = true
  }

  tags = merge({ Name = "ar-elb-www-${var.general.attack_range_name}" },
    var.tags
  )

  depends_on = [aws_s3_bucket_policy.elb_logs]
}

#############################
# this covers HTTPS traffic #
#############################
resource "aws_lb_target_group" "main_https_tg" {
  count    = var.httpd_server.use_alb == "1" ? 1 : 0
  port     = 443
  protocol = "HTTPS"
  vpc_id   = var.aws.vpc_id

  health_check {
    protocol            = "HTTPS"
    path                = "/"
    interval            = "15"
    healthy_threshold   = "2"
    unhealthy_threshold = "2"
    timeout             = "5"
  }

  tags = merge({ Name = "ar-${var.general.key_name}_${var.general.attack_range_name}-https-tg" },
    var.tags
  )
}

resource "aws_lb_target_group_attachment" "apache-httpd_https" {
  count            = var.httpd_server.use_alb == "1" ? 1 : 0
  target_group_arn = aws_lb_target_group.main_https_tg[count.index].arn
  target_id        = var.apache-httpd_instance_id
}

resource "aws_lb_listener" "main_elb_https" {
  count             = var.httpd_server.use_alb == "1" ? 1 : 0
  load_balancer_arn = aws_lb.main_elb[count.index].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = data.aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_https_tg[count.index].arn
  }
}

###########################
# This covers HTTP traffic #
###########################
resource "aws_lb_target_group" "main_http_tg" {
  count    = var.httpd_server.use_alb == "1" ? 1 : 0
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.aws.vpc_id

  health_check {
    protocol            = "HTTP"
    path                = "/"
    interval            = "15"
    healthy_threshold   = "2"
    unhealthy_threshold = "2"
    timeout             = "5"
    port                = "80"
  }

  tags = merge({ Name = "ar-${var.general.key_name}_${var.general.attack_range_name}-http-tg" },
    var.tags
  )
}

resource "aws_lb_target_group_attachment" "apache-httpd_http" {
  count            = var.httpd_server.use_alb == "1" ? 1 : 0
  target_group_arn = aws_lb_target_group.main_http_tg[count.index].arn
  target_id        = var.apache-httpd_instance_id
}

resource "aws_lb_listener" "main_elb_http" {
  count             = var.httpd_server.use_alb == "1" ? 1 : 0
  load_balancer_arn = aws_lb.main_elb[count.index].arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_http_tg[count.index].arn
  }
}

