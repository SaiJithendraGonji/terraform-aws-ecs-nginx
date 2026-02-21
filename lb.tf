resource "aws_lb" "nginx_alb" {
  name               = "${var.environment}-nginx-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public-1.id, aws_subnet.public-2.id]
  security_groups    = [aws_security_group.alb_sg.id]

  enable_deletion_protection = true
  enable_http2               = true

  tags = {
    Name = "${var.environment}-nginx-alb"
  }
}

resource "aws_lb_listener" "nginx_listener" {
  load_balancer_arn = aws_lb.nginx_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.enable_https ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.enable_https ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "forward" {
      for_each = var.enable_https ? [] : [1]
      content {
        target_group {
          arn = aws_lb_target_group.nginx_target_group.arn
        }
      }
    }
  }
}

resource "aws_lb_target_group" "nginx_target_group" {
  name        = "${var.environment}-nginx-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.environment}-nginx-tg"
  }

}

# ACM Certificate, Only created when enable_https = true
resource "aws_acm_certificate" "cert" {
  count             = var.enable_https ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.environment}-acm-cert"
  }
}

# HTTPS Listener, Only created when enable_https = true
resource "aws_lb_listener" "https_listener" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.nginx_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.cert[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_target_group.arn
  }
}

