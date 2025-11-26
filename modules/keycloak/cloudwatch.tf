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

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

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

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

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

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

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
  count = local.is_rds ? 1 : 0

  alarm_name          = "${var.name}-keycloak-db-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Keycloak RDS CPU utilization is above 80%"

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

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
  count = local.is_rds ? 1 : 0

  alarm_name          = "${var.name}-keycloak-db-${var.environment}-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120 # 5 GB in bytes
  alarm_description   = "Keycloak RDS free storage space is below 5 GB"

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

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
  count = local.is_any_aurora ? 1 : 0

  alarm_name          = "${var.name}-keycloak-aurora-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Keycloak Aurora cluster CPU utilization is above 80%"

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

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

# Aurora Serverless v2 high capacity alarm
# Alerts when database capacity approaches the configured maximum ACUs
resource "aws_cloudwatch_metric_alarm" "aurora_serverless_high_capacity" {
  count = local.is_aurora_serverless ? 1 : 0

  alarm_name          = "${var.name}-keycloak-aurora-${var.environment}-high-capacity"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ServerlessDatabaseCapacity"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.db_capacity_max * 0.8 # Alert at 80% of max capacity
  alarm_description   = "Aurora Serverless v2 capacity is above 80% of maximum (${var.db_capacity_max} ACUs). Consider increasing db_capacity_max."

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.keycloak[0].id
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-aurora-${var.environment}-high-capacity"
      Environment = var.environment
    }
  )
}
