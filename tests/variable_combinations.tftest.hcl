# Test different variable combinations
# This test validates that various configuration options work correctly

run "validate_custom_resource_sizing" {
  command = plan

  variables {
    name        = "test-sizing"
    environment = "test"

    # Test different resource sizes
    task_cpu    = 2048
    task_memory = 4096

    # Test different RDS configurations
    db_instance_class          = "db.t4g.small"
    db_allocated_storage       = 50
    db_max_allocated_storage   = 200
    db_backup_retention_period = 14
  }

  module {
    source = "./examples/basic"
  }

  # Verify core resources are created
  assert {
    condition     = length([for r in terraform_plan.resource_changes : r if r.change.actions[0] == "create"]) > 0
    error_message = "Plan should create resources with custom sizing"
  }

  # Verify ECS task definition is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ecs_task_definition" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create ECS task definition with custom CPU/memory"
  }

  # Verify RDS instance is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_db_instance" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create RDS instance with custom configuration"
  }
}

run "validate_monitoring_options" {
  command = plan

  variables {
    name        = "test-monitoring"
    environment = "test"

    # Test monitoring configurations
    enable_container_insights         = false
    cloudwatch_log_retention_days     = 14
    health_check_grace_period_seconds = 300
  }

  module {
    source = "./examples/basic"
  }

  # Verify core resources are created
  assert {
    condition     = length([for r in terraform_plan.resource_changes : r if r.change.actions[0] == "create"]) > 0
    error_message = "Plan should create resources with custom monitoring config"
  }

  # Verify ECS cluster is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ecs_cluster" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create ECS cluster with custom container insights setting"
  }

  # Verify CloudWatch log group is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_cloudwatch_log_group" && r.change.actions[0] == "create"
    ]) >= 1
    error_message = "Should create CloudWatch log group with custom retention"
  }

  # Verify ECS service is created with health check configuration
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ecs_service" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create ECS service with custom health check grace period"
  }
}

run "validate_security_options" {
  command = plan

  variables {
    name        = "test-security"
    environment = "test"

    # Test security configurations
    db_deletion_protection                 = false
    db_skip_final_snapshot                 = true
    db_iam_database_authentication_enabled = true
    alb_deletion_protection                = false
  }

  module {
    source = "./examples/basic"
  }

  # Verify core resources are created
  assert {
    condition     = length([for r in terraform_plan.resource_changes : r if r.change.actions[0] == "create"]) > 0
    error_message = "Plan should create resources with custom security config"
  }

  # Verify RDS instance is created with security settings
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_db_instance" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create RDS instance with custom security configuration"
  }

  # Verify ALB is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_lb" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create ALB with custom deletion protection setting"
  }

  # Verify security groups are created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_security_group" && r.change.actions[0] == "create"
    ]) >= 3
    error_message = "Should create security groups for ALB, ECS, and RDS"
  }
}

run "validate_keycloak_configuration" {
  command = plan

  variables {
    name        = "test-keycloak-config"
    environment = "test"

    # Test Keycloak-specific configurations
    keycloak_version        = "25.0"
    keycloak_loglevel       = "DEBUG"
    keycloak_admin_username = "superadmin"
    keycloak_cache_enabled  = true
    keycloak_cache_stack    = "jdbc-ping"

    # Test connection pool settings
    db_pool_initial_size = 10
    db_pool_min_size     = 10
    db_pool_max_size     = 30
  }

  module {
    source = "./examples/basic"
  }

  # Verify core resources are created
  assert {
    condition     = length([for r in terraform_plan.resource_changes : r if r.change.actions[0] == "create"]) > 0
    error_message = "Plan should create resources with custom Keycloak config"
  }

  # Verify ECS task definition is created with Keycloak configuration
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ecs_task_definition" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create ECS task definition with custom Keycloak version and config"
  }

  # Verify Secrets Manager secrets are created for admin credentials
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_secretsmanager_secret" && r.change.actions[0] == "create"
    ]) >= 2
    error_message = "Should create Secrets Manager secrets for DB and admin credentials"
  }
}

run "validate_high_availability" {
  command = plan

  variables {
    name        = "test-ha"
    environment = "test"

    # Test HA configuration
    multi_az                 = true
    desired_count            = 3
    autoscaling_max_capacity = 9
  }

  module {
    source = "./examples/basic"
  }

  # Verify core resources are created
  assert {
    condition     = length([for r in terraform_plan.resource_changes : r if r.change.actions[0] == "create"]) > 0
    error_message = "Plan should create resources with HA configuration"
  }

  # Verify ECS service is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ecs_service" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create ECS service with HA desired count"
  }

  # Verify autoscaling target is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_appautoscaling_target" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create autoscaling target for HA configuration"
  }

  # Verify autoscaling policies are created (CPU and memory)
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_appautoscaling_policy" && r.change.actions[0] == "create"
    ]) >= 2
    error_message = "Should create at least 2 autoscaling policies (CPU and memory)"
  }

  # Verify RDS with multi-AZ
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_db_instance" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create RDS instance with multi-AZ enabled"
  }
}

run "validate_database_maintenance" {
  command = plan

  variables {
    name        = "test-db-maintenance"
    environment = "test"

    # Test database maintenance windows
    db_backup_window                         = "02:00-03:00"
    db_maintenance_window                    = "mon:03:00-mon:04:00"
    db_engine_version                        = "16.3"
    db_performance_insights_retention_period = 14
  }

  module {
    source = "./examples/basic"
  }

  # Verify core resources are created
  assert {
    condition     = length([for r in terraform_plan.resource_changes : r if r.change.actions[0] == "create"]) > 0
    error_message = "Plan should create resources with database maintenance config"
  }

  # Verify RDS instance is created with maintenance configuration
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_db_instance" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create RDS instance with custom maintenance windows"
  }

  # Verify DB subnet group is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_db_subnet_group" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create DB subnet group"
  }
}
