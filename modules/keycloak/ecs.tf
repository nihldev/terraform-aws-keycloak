#######################
# ECS Cluster
#######################

resource "aws_ecs_cluster" "keycloak" {
  name = "${var.name}-keycloak-${var.environment}"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
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
# ECS Task Definition
#######################

locals {
  # Construct database URL (conditional for RDS vs Aurora)
  db_endpoint = var.database_type == "rds" ? aws_db_instance.keycloak[0].address : aws_rds_cluster.keycloak[0].endpoint
  db_port     = var.database_type == "rds" ? aws_db_instance.keycloak[0].port : aws_rds_cluster.keycloak[0].port
  db_name     = "keycloak"
  db_url      = "jdbc:postgresql://${local.db_endpoint}:${local.db_port}/${local.db_name}"

  # Base environment variables
  base_environment = [
    {
      name  = "KC_DB"
      value = "postgres"
    },
    {
      name  = "KC_DB_URL"
      value = local.db_url
    },
    {
      name  = "KC_DB_USERNAME"
      value = "keycloak"
    },
    {
      name  = "KC_DB_POOL_INITIAL_SIZE"
      value = tostring(var.db_pool_initial_size)
    },
    {
      name  = "KC_DB_POOL_MIN_SIZE"
      value = tostring(var.db_pool_min_size)
    },
    {
      name  = "KC_DB_POOL_MAX_SIZE"
      value = tostring(var.db_pool_max_size)
    },
    {
      name  = "KC_HEALTH_ENABLED"
      value = "true"
    },
    {
      name  = "KC_METRICS_ENABLED"
      value = "true"
    },
    {
      name  = "KC_LOG_LEVEL"
      value = var.keycloak_loglevel
    },
    {
      name  = "KC_PROXY"
      value = "edge"
    },
    {
      name  = "KC_HTTP_ENABLED"
      value = "true"
    },
  ]

  # Hostname configuration (required for production)
  hostname_environment = var.keycloak_hostname != "" ? [
    {
      name  = "KC_HOSTNAME"
      value = var.keycloak_hostname
    },
    {
      name  = "KC_HOSTNAME_STRICT"
      value = "true"
    },
    {
      # Allow health checks from ALB to use backend URL instead of frontend hostname
      name  = "KC_HOSTNAME_STRICT_BACKCHANNEL"
      value = "false"
    },
  ] : []

  # Cache configuration (critical for multi-instance deployments)
  cache_environment = var.keycloak_cache_enabled ? [
    {
      name  = "KC_CACHE"
      value = "ispn"
    },
    {
      name  = "KC_CACHE_STACK"
      value = var.keycloak_cache_stack
    },
  ] : []

  # Convert extra env vars map to list format
  extra_environment = [
    for key, value in var.keycloak_extra_env_vars : {
      name  = key
      value = value
    }
  ]

  # Combine all environment variables
  environment = concat(
    local.base_environment,
    local.hostname_environment,
    local.cache_environment,
    local.extra_environment
  )

  # Secrets
  secrets = [
    {
      name      = "KC_DB_PASSWORD"
      valueFrom = "${aws_secretsmanager_secret.keycloak_db.arn}:password::"
    },
    {
      name      = "KEYCLOAK_ADMIN"
      valueFrom = "${aws_secretsmanager_secret.keycloak_admin.arn}:username::"
    },
    {
      name      = "KEYCLOAK_ADMIN_PASSWORD"
      valueFrom = "${aws_secretsmanager_secret.keycloak_admin.arn}:password::"
    },
  ]
}

resource "aws_ecs_task_definition" "keycloak" {
  family                   = "${var.name}-keycloak-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "keycloak"
      image = local.keycloak_image

      # Using 'start' instead of 'start --optimized' to allow runtime configuration
      # and proper database initialization on first deployment
      command = ["start"]

      essential = true

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      environment = local.environment
      secrets     = local.secrets

      # Health Check Architecture:
      # -------------------------
      # Three health check mechanisms work together:
      #
      # 1. Container Health Check (this block):
      #    - Used by ECS to monitor container health
      #    - startPeriod: 60s grace before checks count (Keycloak startup time)
      #    - interval: 30s, timeout: 5s, retries: 3
      #    - If unhealthy, ECS stops and replaces the task
      #
      # 2. ALB Target Group Health Check (networking.tf):
      #    - Used by ALB to route traffic to healthy targets
      #    - interval: 30s, timeout: 5s
      #    - healthy_threshold: 2, unhealthy_threshold: 3
      #    - Path: var.health_check_path (default: /health/ready)
      #
      # 3. ECS Service Grace Period (var.health_check_grace_period_seconds):
      #    - Default: 600s (10 minutes)
      #    - Time before ECS considers ALB health check failures
      #    - Allows Keycloak to fully initialize (DB migrations, cache warmup)
      #
      # Timeline for new deployment:
      #   0s-60s:   Container starting (startPeriod, checks don't count)
      #   60s-90s:  Container health checks begin
      #   ~90s:     ALB starts receiving healthy responses
      #   ~120s:    ALB marks target healthy (2 consecutive checks)
      #   0s-600s:  ECS ignores ALB failures (grace period)
      #
      healthCheck = {
        command = [
          "CMD-SHELL",
          "exec 3<>/dev/tcp/localhost/8080 && echo -e 'GET /health/ready HTTP/1.1\\r\\nHost: localhost\\r\\nConnection: close\\r\\n\\r\\n' >&3 && cat <&3 | grep -q '200 OK'"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.keycloak.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "keycloak"
        }
      }
    }
  ])

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-${var.environment}"
      Environment = var.environment
    }
  )
}

#######################
# ECS Service
#######################

resource "aws_ecs_service" "keycloak" {
  name            = "${var.name}-keycloak-${var.environment}"
  cluster         = aws_ecs_cluster.keycloak.id
  task_definition = aws_ecs_task_definition.keycloak.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  platform_version = "LATEST"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.keycloak.arn
    container_name   = "keycloak"
    container_port   = 8080
  }

  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  # Deployment configuration for zero-downtime updates
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # Deployment circuit breaker for automatic rollback on failures
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Note: ordered_placement_strategy is not supported for Fargate launch type
  # Fargate automatically spreads tasks across AZs when using multiple subnets

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy.ecs_task_execution_secrets,
  ]

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-${var.environment}"
      Environment = var.environment
    }
  )
}

#######################
# Auto Scaling
#######################

resource "aws_appautoscaling_target" "keycloak" {
  max_capacity       = var.autoscaling_max_capacity != null ? var.autoscaling_max_capacity : var.desired_count * 3
  min_capacity       = var.desired_count
  resource_id        = "service/${aws_ecs_cluster.keycloak.name}/${aws_ecs_service.keycloak.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-autoscaling-${var.environment}"
      Environment = var.environment
    }
  )
}

# Scale up based on CPU
resource "aws_appautoscaling_policy" "keycloak_cpu" {
  name               = "${var.name}-keycloak-${var.environment}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.keycloak.resource_id
  scalable_dimension = aws_appautoscaling_target.keycloak.scalable_dimension
  service_namespace  = aws_appautoscaling_target.keycloak.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# Scale up based on memory
resource "aws_appautoscaling_policy" "keycloak_memory" {
  name               = "${var.name}-keycloak-${var.environment}-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.keycloak.resource_id
  scalable_dimension = aws_appautoscaling_target.keycloak.scalable_dimension
  service_namespace  = aws_appautoscaling_target.keycloak.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}

#######################
# Data Sources
#######################

data "aws_region" "current" {}
