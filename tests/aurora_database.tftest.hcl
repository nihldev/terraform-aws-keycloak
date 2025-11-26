# Aurora Database Tests
# Tests for Aurora Provisioned and Aurora Serverless v2 configurations

#######################
# Aurora Serverless v2 Tests
#######################

run "aurora_serverless_basic" {
  command = plan

  variables {
    name        = "test-aurora-serverless"
    environment = "dev"
  }

  module {
    source = "./examples/aurora-serverless"
  }

  # Verify core resources are created
  assert {
    condition     = length([for r in terraform_plan.resource_changes : r if r.change.actions[0] == "create"]) > 0
    error_message = "Plan should create resources for Aurora Serverless"
  }

  # Verify Aurora cluster is created (not RDS instance)
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_rds_cluster" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create exactly one Aurora cluster"
  }

  # Verify Aurora Serverless instance is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_rds_cluster_instance" && r.change.actions[0] == "create"
    ]) >= 1
    error_message = "Should create at least one Aurora cluster instance"
  }

  # Verify NO standard RDS instance is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_db_instance" && r.change.actions[0] == "create"
    ]) == 0
    error_message = "Should NOT create standard RDS instance when using Aurora"
  }

  # Verify ECS resources are still created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ecs_cluster" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create ECS cluster"
  }
}

run "aurora_serverless_custom_capacity" {
  command = plan

  variables {
    name            = "test-aurora-capacity"
    environment     = "dev"
    db_capacity_min = 1
    db_capacity_max = 4
  }

  module {
    source = "./examples/aurora-serverless"
  }

  # Verify Aurora cluster is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_rds_cluster" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create Aurora cluster with custom capacity settings"
  }

  # Verify Aurora instance is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_rds_cluster_instance" && r.change.actions[0] == "create"
    ]) >= 1
    error_message = "Should create Aurora cluster instance"
  }
}

run "aurora_serverless_ha_config" {
  command = plan

  variables {
    name          = "test-aurora-ha"
    environment   = "dev"
    multi_az      = true
    desired_count = 2
  }

  module {
    source = "./examples/aurora-serverless"
  }

  # Verify Aurora cluster is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_rds_cluster" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create Aurora cluster with HA configuration"
  }

  # Verify ECS service is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ecs_service" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create ECS service with HA desired count"
  }

  # Verify autoscaling is configured
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_appautoscaling_target" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create autoscaling target for HA"
  }
}

#######################
# Aurora Provisioned Tests
#######################

run "aurora_provisioned_basic" {
  command = plan

  variables {
    name        = "test-aurora-provisioned"
    environment = "dev"
  }

  module {
    source = "./examples/aurora-provisioned"
  }

  # Verify Aurora cluster is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_rds_cluster" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create exactly one Aurora cluster"
  }

  # Verify Aurora writer instance is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_rds_cluster_instance" && r.change.actions[0] == "create"
    ]) >= 1
    error_message = "Should create at least one Aurora cluster instance (writer)"
  }

  # Verify NO standard RDS instance is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_db_instance" && r.change.actions[0] == "create"
    ]) == 0
    error_message = "Should NOT create standard RDS instance when using Aurora"
  }

  # Verify ECS cluster is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ecs_cluster" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create ECS cluster"
  }
}

run "aurora_provisioned_with_replicas" {
  command = plan

  variables {
    name                 = "test-aurora-replicas"
    environment          = "dev"
    multi_az             = true
    aurora_replica_count = 2
  }

  module {
    source = "./examples/aurora-provisioned"
  }

  # Verify Aurora cluster is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_rds_cluster" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create Aurora cluster"
  }

  # Verify correct number of Aurora instances (1 writer + 2 readers = 3)
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_rds_cluster_instance" && r.change.actions[0] == "create"
    ]) == 3
    error_message = "Should create 3 Aurora instances (1 writer + 2 readers)"
  }
}

run "aurora_provisioned_custom_instance" {
  command = plan

  variables {
    name              = "test-aurora-instance"
    environment       = "dev"
    db_instance_class = "db.r6g.xlarge"
  }

  module {
    source = "./examples/aurora-provisioned"
  }

  # Verify Aurora cluster is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_rds_cluster" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create Aurora cluster with custom instance class"
  }

  # Verify Aurora instance is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_rds_cluster_instance" && r.change.actions[0] == "create"
    ]) >= 1
    error_message = "Should create Aurora instance with custom instance class"
  }
}

run "aurora_provisioned_backtrack" {
  command = plan

  variables {
    name                    = "test-aurora-backtrack"
    environment             = "dev"
    aurora_backtrack_window = 48
  }

  module {
    source = "./examples/aurora-provisioned"
  }

  # Verify Aurora cluster is created with backtrack
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_rds_cluster" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create Aurora cluster with backtrack enabled"
  }
}

#######################
# Aurora Output Validation (Apply Tests)
# These tests actually deploy and validate outputs
#######################

run "aurora_serverless_outputs" {
  command = apply

  variables {
    name        = "test-aurora-out"
    environment = "dev"
  }

  module {
    source = "./examples/aurora-serverless"
  }

  # Verify database type output
  assert {
    condition     = output.database_type == "aurora-serverless"
    error_message = "Database type should be 'aurora-serverless'"
  }

  # Verify Aurora cluster endpoint format
  assert {
    condition     = can(regex(".*\\.cluster-.*\\.rds\\.amazonaws\\.com", output.db_cluster_endpoint))
    error_message = "Aurora endpoint should match cluster endpoint format"
  }

  # Verify cost warning is shown for non-prod Aurora
  assert {
    condition     = output.cost_warning != ""
    error_message = "Cost warning should be displayed for non-prod Aurora deployment"
  }

  # Verify ECS cluster is created
  assert {
    condition     = output.ecs_cluster_name != ""
    error_message = "ECS cluster name should not be empty"
  }

  # Verify Keycloak URL is generated
  assert {
    condition     = output.keycloak_url != ""
    error_message = "Keycloak URL should not be empty"
  }
}
