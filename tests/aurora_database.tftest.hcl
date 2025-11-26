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

  assert {
    condition     = length([for r in terraform_plan.resource_changes : r if r.change.actions[0] == "create"]) > 0
    error_message = "Plan should create resources for Aurora Serverless"
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

  assert {
    condition     = length([for r in terraform_plan.resource_changes : r if r.change.actions[0] == "create"]) > 0
    error_message = "Plan should create resources with custom Aurora Serverless capacity"
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

  assert {
    condition     = length([for r in terraform_plan.resource_changes : r if r.change.actions[0] == "create"]) > 0
    error_message = "Plan should create resources with HA configuration for Aurora Serverless"
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

  assert {
    condition     = length([for r in terraform_plan.resource_changes : r if r.change.actions[0] == "create"]) > 0
    error_message = "Plan should create resources for Aurora Provisioned"
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

  assert {
    condition     = length([for r in terraform_plan.resource_changes : r if r.change.actions[0] == "create"]) > 0
    error_message = "Plan should create resources with Aurora read replicas"
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

  assert {
    condition     = length([for r in terraform_plan.resource_changes : r if r.change.actions[0] == "create"]) > 0
    error_message = "Plan should create resources with custom Aurora instance class"
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

  assert {
    condition     = length([for r in terraform_plan.resource_changes : r if r.change.actions[0] == "create"]) > 0
    error_message = "Plan should create resources with Aurora backtrack enabled"
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
