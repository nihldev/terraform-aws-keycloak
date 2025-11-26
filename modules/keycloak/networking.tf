#######################
# Security Group - ALB
#######################

resource "aws_security_group" "alb" {
  name_prefix = "${var.name}-keycloak-alb-${var.environment}-"
  description = "Security group for Keycloak Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-alb-${var.environment}"
      Environment = var.environment
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# tfsec:ignore:aws-ec2-no-public-ingress-sgr -- ALB ingress for Keycloak authentication.
# Access restricted via allowed_cidr_blocks (0.0.0.0/0 blocked in prod by validation).
resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP inbound traffic"
}

# tfsec:ignore:aws-ec2-no-public-ingress-sgr -- ALB ingress for Keycloak authentication.
# Access restricted via allowed_cidr_blocks (0.0.0.0/0 blocked in prod by validation).
resource "aws_security_group_rule" "alb_ingress_https" {
  count             = var.certificate_arn != "" ? 1 : 0
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS inbound traffic"
}

# Allow ALB to forward traffic to ECS tasks on Keycloak port
# Restricted to ECS security group for least-privilege security
resource "aws_security_group_rule" "alb_egress_to_ecs" {
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = aws_security_group.alb.id
  description              = "Allow traffic to ECS tasks on Keycloak port"
}

#######################
# Security Group - ECS Tasks
#######################

resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${var.name}-keycloak-ecs-${var.environment}-"
  description = "Security group for Keycloak ECS tasks"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-ecs-${var.environment}"
      Environment = var.environment
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ecs_tasks_ingress_from_alb" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs_tasks.id
  description              = "Allow traffic from ALB to ECS tasks"
}

# Allow all outbound traffic for ECS tasks
# Required for:
# - Pulling container images from quay.io
# - Connecting to RDS database (via security group, not CIDR)
# - External OIDC/SAML providers and APIs
# - DNS resolution
# - NTP time sync
# Actual database access is controlled by RDS security group ingress rules
# tfsec:ignore:aws-ec2-no-public-egress-sgr -- Required for container images, external IdP integration, DNS, NTP.
resource "aws_security_group_rule" "ecs_tasks_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "Allow all outbound traffic for container operations and external integrations"
}

#######################
# Application Load Balancer
#######################

# tfsec:ignore:aws-elb-alb-not-public -- Keycloak is a user-facing IdP requiring public access.
# Protected by WAF (required for prod), CIDR restrictions, and deletion protection.
resource "aws_lb" "keycloak" {
  name               = "${var.name}-keycloak-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.alb_deletion_protection != null ? var.alb_deletion_protection : (var.environment == "prod" ? true : false)
  enable_http2               = true
  drop_invalid_header_fields = true

  dynamic "access_logs" {
    for_each = var.alb_access_logs_enabled ? [1] : []
    content {
      enabled = true
      bucket  = var.alb_access_logs_bucket
      prefix  = var.alb_access_logs_prefix != "" ? var.alb_access_logs_prefix : "${var.name}-keycloak-${var.environment}"
    }
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-${var.environment}"
      Environment = var.environment
    }
  )
}

#######################
# WAF Association (Optional)
#######################

resource "aws_wafv2_web_acl_association" "keycloak" {
  count        = var.waf_acl_arn != "" ? 1 : 0
  resource_arn = aws_lb.keycloak.arn
  web_acl_arn  = var.waf_acl_arn
}

#######################
# Target Group
#######################

resource "aws_lb_target_group" "keycloak" {
  name        = "${var.name}-keycloak-${var.environment}"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-${var.environment}"
      Environment = var.environment
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

#######################
# Listeners
#######################

# HTTP Listener - redirect to HTTPS if certificate is provided, otherwise forward to target group
# tfsec:ignore:aws-elb-http-not-used -- Redirects to HTTPS when certificate configured, or serves dev/test.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.keycloak.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.certificate_arn != "" ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.certificate_arn != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    target_group_arn = var.certificate_arn != "" ? null : aws_lb_target_group.keycloak.arn
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-http-${var.environment}"
      Environment = var.environment
    }
  )
}

# HTTPS Listener - only created if certificate is provided
resource "aws_lb_listener" "https" {
  count             = var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.keycloak.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.keycloak.arn
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-https-${var.environment}"
      Environment = var.environment
    }
  )
}
