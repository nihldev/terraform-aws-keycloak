#######################
# CloudWatch Log Group
#######################

resource "aws_cloudwatch_log_group" "keycloak" {
  name              = "/ecs/${var.name}-keycloak-${var.environment}"
  retention_in_days = var.cloudwatch_log_retention_days != null ? var.cloudwatch_log_retention_days : (var.environment == "prod" ? 30 : 7)

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-${var.environment}"
      Environment = var.environment
    }
  )
}

#######################
# CloudWatch Alarms
#######################

# High CPU utilization alarm
resource "aws_cloudwatch_metric_alarm" "ecs_high_cpu" {
  alarm_name          = "${var.name}-keycloak-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Keycloak ECS CPU utilization is above 80%"

  dimensions = {
    ClusterName = aws_ecs_cluster.keycloak.name
    ServiceName = aws_ecs_service.keycloak.name
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-${var.environment}-high-cpu"
      Environment = var.environment
    }
  )
}

# High memory utilization alarm
resource "aws_cloudwatch_metric_alarm" "ecs_high_memory" {
  alarm_name          = "${var.name}-keycloak-${var.environment}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Keycloak ECS memory utilization is above 80%"

  dimensions = {
    ClusterName = aws_ecs_cluster.keycloak.name
    ServiceName = aws_ecs_service.keycloak.name
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-${var.environment}-high-memory"
      Environment = var.environment
    }
  )
}

# Target group unhealthy targets alarm
resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${var.name}-keycloak-${var.environment}-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Keycloak has unhealthy targets"

  dimensions = {
    LoadBalancer = aws_lb.keycloak.arn_suffix
    TargetGroup  = aws_lb_target_group.keycloak.arn_suffix
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-${var.environment}-unhealthy-targets"
      Environment = var.environment
    }
  )
}

# RDS high CPU alarm
resource "aws_cloudwatch_metric_alarm" "rds_high_cpu" {
  count = var.database_type == "rds" ? 1 : 0

  alarm_name          = "${var.name}-keycloak-db-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Keycloak RDS CPU utilization is above 80%"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.keycloak[0].id
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-db-${var.environment}-high-cpu"
      Environment = var.environment
    }
  )
}

# RDS low storage space alarm
resource "aws_cloudwatch_metric_alarm" "rds_low_storage" {
  count = var.database_type == "rds" ? 1 : 0

  alarm_name          = "${var.name}-keycloak-db-${var.environment}-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120 # 5 GB in bytes
  alarm_description   = "Keycloak RDS free storage space is below 5 GB"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.keycloak[0].id
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-db-${var.environment}-low-storage"
      Environment = var.environment
    }
  )
}

# Aurora high CPU alarm
resource "aws_cloudwatch_metric_alarm" "aurora_high_cpu" {
  count = contains(["aurora", "aurora-serverless"], var.database_type) ? 1 : 0

  alarm_name          = "${var.name}-keycloak-aurora-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Keycloak Aurora cluster CPU utilization is above 80%"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.keycloak[0].id
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-aurora-${var.environment}-high-cpu"
      Environment = var.environment
    }
  )
}
