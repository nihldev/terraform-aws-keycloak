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

output "get_admin_credentials_command" {
  description = "AWS CLI command to retrieve admin credentials"
  value       = "aws secretsmanager get-secret-value --secret-id ${module.keycloak.admin_credentials_secret_arn} --query SecretString --output text | jq -r '.username, .password'"
}
