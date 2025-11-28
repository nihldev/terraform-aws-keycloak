# Test module resource creation and configuration
run "validate_module_resources" {
  command = plan

  variables {
    name        = "test-keycloak"
    environment = "test"
  }

  module {
    source = "./examples/basic"
  }

  # Verify plan creates expected resources
  assert {
    condition     = length([for r in terraform_plan.resource_changes : r if r.change.actions[0] == "create"]) > 0
    error_message = "Plan should create resources"
  }

  # Verify ECS cluster is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ecs_cluster" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create exactly one ECS cluster"
  }

  # Verify ECS cluster has Container Insights enabled by default
  assert {
    condition = alltrue([
      for r in terraform_plan.resource_changes : (
        length([for s in r.change.after.setting : s if s.name == "containerInsights" && s.value == "enabled"]) == 1
      )
      if r.type == "aws_ecs_cluster" && r.change.actions[0] == "create"
    ])
    error_message = "ECS cluster should have Container Insights enabled by default"
  }

  # Verify ECS service is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ecs_service" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create exactly one ECS service"
  }

  # Verify ECS task definition is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ecs_task_definition" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create exactly one ECS task definition"
  }

  # Verify ECS task definition uses Fargate
  assert {
    condition = alltrue([
      for r in terraform_plan.resource_changes : contains(r.change.after.requires_compatibilities, "FARGATE")
      if r.type == "aws_ecs_task_definition" && r.change.actions[0] == "create"
    ])
    error_message = "ECS task definition should require FARGATE compatibility"
  }

  # Verify RDS instance is created (default database_type is "rds")
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_db_instance" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create exactly one RDS instance"
  }

  # Verify RDS instance uses PostgreSQL engine
  assert {
    condition = alltrue([
      for r in terraform_plan.resource_changes : r.change.after.engine == "postgres"
      if r.type == "aws_db_instance" && r.change.actions[0] == "create"
    ])
    error_message = "RDS instance should use PostgreSQL engine"
  }

  # Verify RDS instance has storage encryption enabled
  assert {
    condition = alltrue([
      for r in terraform_plan.resource_changes : r.change.after.storage_encrypted == true
      if r.type == "aws_db_instance" && r.change.actions[0] == "create"
    ])
    error_message = "RDS instance should have storage encryption enabled"
  }

  # Verify RDS instance has Performance Insights enabled
  assert {
    condition = alltrue([
      for r in terraform_plan.resource_changes : r.change.after.performance_insights_enabled == true
      if r.type == "aws_db_instance" && r.change.actions[0] == "create"
    ])
    error_message = "RDS instance should have Performance Insights enabled"
  }

  # Verify ALB is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_lb" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create exactly one Application Load Balancer"
  }

  # Verify ALB has invalid header dropping enabled
  assert {
    condition = alltrue([
      for r in terraform_plan.resource_changes : r.change.after.drop_invalid_header_fields == true
      if r.type == "aws_lb" && r.change.actions[0] == "create"
    ])
    error_message = "ALB should drop invalid header fields for security"
  }

  # Verify ALB target group is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_lb_target_group" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create exactly one ALB target group"
  }

  # Verify ALB target group health check uses correct path
  assert {
    condition = alltrue([
      for r in terraform_plan.resource_changes : r.change.after.health_check[0].path == "/health/ready"
      if r.type == "aws_lb_target_group" && r.change.actions[0] == "create"
    ])
    error_message = "ALB target group health check should use /health/ready path"
  }

  # Verify security groups are created (ALB, ECS, RDS = 3)
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_security_group" && r.change.actions[0] == "create"
    ]) >= 3
    error_message = "Should create at least 3 security groups (ALB, ECS, RDS)"
  }

  # Verify Secrets Manager secrets are created (DB credentials, admin credentials)
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_secretsmanager_secret" && r.change.actions[0] == "create"
    ]) >= 2
    error_message = "Should create at least 2 Secrets Manager secrets"
  }

  # Verify Secrets Manager secrets have 7-day recovery window
  assert {
    condition = alltrue([
      for r in terraform_plan.resource_changes : r.change.after.recovery_window_in_days == 7
      if r.type == "aws_secretsmanager_secret" && r.change.actions[0] == "create"
    ])
    error_message = "Secrets Manager secrets should have 7-day recovery window"
  }

  # Verify CloudWatch log group is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_cloudwatch_log_group" && r.change.actions[0] == "create"
    ]) >= 1
    error_message = "Should create at least one CloudWatch log group"
  }

  # Verify IAM roles are created (execution role, task role)
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_iam_role" && r.change.actions[0] == "create"
    ]) >= 2
    error_message = "Should create at least 2 IAM roles (execution and task roles)"
  }

  # Verify autoscaling target is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_appautoscaling_target" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create exactly one autoscaling target"
  }
}
