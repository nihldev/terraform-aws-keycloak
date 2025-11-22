config {
  call_module_type = "all"
  force            = false
}

plugin "aws" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

#######################
# Terraform Best Practices
#######################

rule "terraform_naming_convention" {
  enabled = true

  format = "snake_case"
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = true
}

rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_workspace_remote" {
  enabled = true
}

#######################
# AWS-Specific Rules
#######################

rule "aws_resource_missing_tags" {
  enabled = true
  tags = ["Name", "Environment"]
}

# Prevent deprecated instance types
rule "aws_db_instance_previous_type" {
  enabled = true
}

# Note: aws_ecs_task_definition_previous_container_runtime rule doesn't exist in current plugin version
# Removed to prevent errors

rule "aws_instance_previous_type" {
  enabled = true
}

# Ensure proper configuration
rule "aws_db_instance_default_parameter_group" {
  enabled = true
}

rule "aws_elasticache_cluster_default_parameter_group" {
  enabled = true
}

rule "aws_route_not_specified_target" {
  enabled = true
}

rule "aws_route_specified_multiple_targets" {
  enabled = true
}

#######################
# Security Rules
#######################

rule "aws_iam_policy_document_gov_friendly_arns" {
  enabled = true
}

rule "aws_iam_role_policy_gov_friendly_arns" {
  enabled = true
}

rule "aws_iam_policy_gov_friendly_arns" {
  enabled = true
}
