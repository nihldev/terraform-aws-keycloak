# SES Email Integration Tests
# Tests for AWS SES email configuration with Keycloak

#######################
# SES Basic Configuration Tests
#######################

run "ses_basic_enabled" {
  command = plan

  variables {
    name        = "test-ses-basic"
    environment = "dev"
    enable_ses  = true
    ses_domain  = "test-keycloak.example.com"
  }

  module {
    source = "./examples/ses-email"
  }

  # Verify core resources are created
  assert {
    condition     = length([for r in terraform_plan.resource_changes : r if r.change.actions[0] == "create"]) > 0
    error_message = "Plan should create resources with SES enabled"
  }

  # Verify SES domain identity is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ses_domain_identity" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create exactly one SES domain identity"
  }

  # Verify SES DKIM is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ses_domain_dkim" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create SES DKIM configuration"
  }

  # Verify IAM user for SMTP is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_iam_user" && r.change.actions[0] == "create"
    ]) >= 1
    error_message = "Should create IAM user for SES SMTP"
  }

  # Verify IAM access key is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_iam_access_key" && r.change.actions[0] == "create"
    ]) >= 1
    error_message = "Should create IAM access key for SES SMTP"
  }

  # Verify Secrets Manager secret for SMTP credentials is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_secretsmanager_secret" && r.change.actions[0] == "create"
    ]) >= 3
    error_message = "Should create at least 3 secrets (DB, admin, SES SMTP)"
  }

  # Verify ECS cluster is still created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ecs_cluster" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create ECS cluster alongside SES"
  }
}

run "ses_with_email_identity" {
  command = plan

  variables {
    name               = "test-ses-email-id"
    environment        = "dev"
    enable_ses         = true
    ses_domain         = "test-keycloak.example.com"
    ses_email_identity = "noreply@test-keycloak.example.com"
  }

  module {
    source = "./examples/ses-email"
  }

  # Verify SES domain identity is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ses_domain_identity" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create SES domain identity"
  }

  # Verify SES email identity is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ses_email_identity" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create SES email identity when specified"
  }
}

run "ses_with_custom_from_email" {
  command = plan

  variables {
    name           = "test-ses-from"
    environment    = "dev"
    enable_ses     = true
    ses_domain     = "test-keycloak.example.com"
    ses_from_email = "keycloak@test-keycloak.example.com"
  }

  module {
    source = "./examples/ses-email"
  }

  # Verify SES domain identity is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ses_domain_identity" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create SES domain identity with custom from email"
  }

  # Verify SMTP credentials secret is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_secretsmanager_secret" && r.change.actions[0] == "create"
    ]) >= 3
    error_message = "Should create secrets including SES SMTP credentials"
  }
}

run "ses_with_configuration_set" {
  command = plan

  variables {
    name                          = "test-ses-config-set"
    environment                   = "dev"
    enable_ses                    = true
    ses_domain                    = "test-keycloak.example.com"
    ses_configuration_set_enabled = true
  }

  module {
    source = "./examples/ses-email"
  }

  # Verify SES configuration set is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ses_configuration_set" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create SES configuration set when enabled"
  }

  # Verify SES event destination is created for CloudWatch
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ses_event_destination" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create SES event destination for metrics"
  }

  # Verify SES domain identity is still created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ses_domain_identity" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should create SES domain identity"
  }
}

run "ses_disabled" {
  command = plan

  variables {
    name        = "test-ses-disabled"
    environment = "dev"
    enable_ses  = false
    ses_domain  = ""
  }

  module {
    source = "./examples/ses-email"
  }

  # Verify core Keycloak resources are created
  assert {
    condition     = length([for r in terraform_plan.resource_changes : r if r.change.actions[0] == "create"]) > 0
    error_message = "Plan should create resources without SES"
  }

  # Verify NO SES domain identity is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ses_domain_identity" && r.change.actions[0] == "create"
    ]) == 0
    error_message = "Should NOT create SES domain identity when SES is disabled"
  }

  # Verify NO SES DKIM is created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ses_domain_dkim" && r.change.actions[0] == "create"
    ]) == 0
    error_message = "Should NOT create SES DKIM when SES is disabled"
  }

  # Verify only 2 secrets are created (DB and admin, not SES)
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_secretsmanager_secret" && r.change.actions[0] == "create"
    ]) == 2
    error_message = "Should create exactly 2 secrets (DB and admin) when SES is disabled"
  }

  # Verify ECS cluster is still created
  assert {
    condition = length([
      for r in terraform_plan.resource_changes : r
      if r.type == "aws_ecs_cluster" && r.change.actions[0] == "create"
    ]) == 1
    error_message = "Should still create ECS cluster when SES is disabled"
  }
}

#######################
# SES Output Validation (Apply Tests)
# These tests actually deploy and validate outputs
#######################

run "ses_outputs_validation" {
  command = apply

  variables {
    name        = "test-ses-out"
    environment = "dev"
    enable_ses  = true
    ses_domain  = "test-keycloak.example.com"
  }

  module {
    source = "./examples/ses-email"
  }

  # Verify SES domain identity is created
  assert {
    condition     = output.ses_domain_identity_arn != ""
    error_message = "SES domain identity ARN should not be empty"
  }

  # Verify SES domain identity ARN format
  assert {
    condition     = can(regex("^arn:aws:ses:.*:identity/", output.ses_domain_identity_arn))
    error_message = "SES domain identity ARN should match expected format"
  }

  # Verify domain verification token is generated
  assert {
    condition     = output.ses_domain_verification_token != ""
    error_message = "SES domain verification token should not be empty"
  }

  # Verify DKIM tokens are generated (should be 3)
  assert {
    condition     = length(output.ses_dkim_tokens) == 3
    error_message = "SES should generate exactly 3 DKIM tokens"
  }

  # Verify SMTP endpoint is correctly formatted
  assert {
    condition     = can(regex("^email-smtp\\..+\\.amazonaws\\.com$", output.ses_smtp_endpoint))
    error_message = "SES SMTP endpoint should match AWS SES format"
  }

  # Verify SMTP credentials secret is created
  assert {
    condition     = output.ses_smtp_credentials_secret_arn != ""
    error_message = "SES SMTP credentials secret ARN should not be empty"
  }

  # Verify from email is set correctly
  assert {
    condition     = output.ses_from_email == "noreply@test-keycloak.example.com"
    error_message = "SES from email should default to noreply@domain"
  }

  # Verify DNS records are provided (since no Route53 zone)
  assert {
    condition     = output.ses_dns_records_required != null
    error_message = "SES DNS records should be provided when Route53 zone is not specified"
  }

  # Verify Keycloak resources are still created
  assert {
    condition     = output.keycloak_url != ""
    error_message = "Keycloak URL should not be empty"
  }

  assert {
    condition     = output.ecs_cluster_name != ""
    error_message = "ECS cluster name should not be empty"
  }
}

run "ses_custom_from_email_output" {
  command = apply

  variables {
    name           = "test-ses-custom"
    environment    = "dev"
    enable_ses     = true
    ses_domain     = "test-keycloak.example.com"
    ses_from_email = "auth@test-keycloak.example.com"
  }

  module {
    source = "./examples/ses-email"
  }

  # Verify custom from email is used
  assert {
    condition     = output.ses_from_email == "auth@test-keycloak.example.com"
    error_message = "SES from email should match custom value"
  }
}

run "ses_configuration_set_output" {
  command = apply

  variables {
    name                          = "test-ses-cfgset"
    environment                   = "dev"
    enable_ses                    = true
    ses_domain                    = "test-keycloak.example.com"
    ses_configuration_set_enabled = true
  }

  module {
    source = "./examples/ses-email"
  }

  # Verify configuration set is created
  assert {
    condition     = output.ses_configuration_set_name != ""
    error_message = "SES configuration set name should not be empty when enabled"
  }

  # Verify configuration set name format
  assert {
    condition     = can(regex("^test-ses-cfgset-keycloak-dev$", output.ses_configuration_set_name))
    error_message = "SES configuration set name should follow naming convention"
  }
}
