# Comprehensive output validation test
run "validate_all_outputs" {
  command = apply

  module {
    source = "./examples/basic"
  }

  #######################
  # ALB Outputs
  #######################
  assert {
    condition     = output.keycloak_url != ""
    error_message = "Keycloak URL should not be empty"
  }

  assert {
    condition     = can(regex("^http://", output.keycloak_url))
    error_message = "Keycloak URL should start with http:// for basic example (no certificate)"
  }

  assert {
    condition     = output.alb_dns_name != ""
    error_message = "ALB DNS name should not be empty"
  }

  assert {
    condition     = can(regex(".*\\.elb\\.amazonaws\\.com$", output.alb_dns_name))
    error_message = "ALB DNS name should match AWS ELB format"
  }

  #######################
  # ECS Outputs
  #######################
  assert {
    condition     = output.ecs_cluster_name != ""
    error_message = "ECS cluster name should not be empty"
  }

  assert {
    condition     = can(regex("^[a-zA-Z0-9-]+$", output.ecs_cluster_name))
    error_message = "ECS cluster name should contain only alphanumeric characters and hyphens"
  }

  #######################
  # RDS Outputs
  #######################
  assert {
    condition     = output.db_instance_endpoint != ""
    error_message = "RDS endpoint should not be empty"
  }

  assert {
    condition     = can(regex(".*\\.rds\\.amazonaws\\.com:5432$", output.db_instance_endpoint))
    error_message = "RDS endpoint should match AWS RDS format with port 5432"
  }

  #######################
  # Secrets Manager Outputs
  #######################
  assert {
    condition     = output.admin_credentials_secret_id != ""
    error_message = "Admin credentials secret ID should not be empty"
  }

  assert {
    condition     = can(regex("^arn:aws:secretsmanager:", output.admin_credentials_secret_id))
    error_message = "Admin credentials secret ID should be a valid ARN"
  }

  #######################
  # VPC Output
  #######################
  assert {
    condition     = output.vpc_id != ""
    error_message = "VPC ID should not be empty"
  }

  assert {
    condition     = can(regex("^vpc-[a-f0-9]+$", output.vpc_id))
    error_message = "VPC ID should match AWS VPC ID format"
  }

  #######################
  # URL Consistency
  #######################
  assert {
    condition     = can(regex(output.alb_dns_name, output.keycloak_url))
    error_message = "Keycloak URL should contain the ALB DNS name"
  }
}
