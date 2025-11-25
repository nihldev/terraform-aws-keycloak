output "keycloak_url" {
  description = "URL to access Keycloak"
  value       = module.keycloak.keycloak_url
}

output "keycloak_admin_console_url" {
  description = "URL to access Keycloak admin console"
  value       = module.keycloak.keycloak_admin_console_url
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.keycloak.alb_dns_name
}

output "admin_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Keycloak admin credentials"
  value       = module.keycloak.admin_credentials_secret_arn
}

output "db_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  value       = module.keycloak.db_credentials_secret_arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "database_type" {
  description = "Database type deployed"
  value       = module.keycloak.database_type
}

output "db_instance_endpoint" {
  description = "Database writer endpoint"
  value       = module.keycloak.db_instance_endpoint
}

output "db_reader_endpoint" {
  description = "Aurora cluster reader endpoint (empty for RDS)"
  value       = module.keycloak.db_reader_endpoint
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.keycloak.ecs_cluster_name
}

output "cost_warning" {
  description = "Cost optimization recommendations"
  value       = module.keycloak.cost_warning
}

output "get_admin_credentials_command" {
  description = "AWS CLI command to retrieve admin credentials"
  value       = "aws secretsmanager get-secret-value --secret-id ${module.keycloak.admin_credentials_secret_arn} --query SecretString --output text | jq -r '.username, .password'"
}
