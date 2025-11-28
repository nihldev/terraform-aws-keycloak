output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "keycloak_url" {
  description = "Keycloak URL"
  value       = module.keycloak.keycloak_url
}

output "keycloak_admin_console_url" {
  description = "Keycloak admin console URL"
  value       = module.keycloak.keycloak_admin_console_url
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.keycloak.alb_dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.keycloak.ecs_cluster_name
}

output "database_type" {
  description = "Database type deployed"
  value       = module.keycloak.database_type
}

output "db_cluster_endpoint" {
  description = "Aurora Serverless cluster endpoint"
  value       = module.keycloak.db_instance_endpoint
}

output "admin_credentials_secret_id" {
  description = "Admin credentials secret ID"
  value       = module.keycloak.admin_credentials_secret_id
}

output "db_credentials_secret_id" {
  description = "Database credentials secret ID"
  value       = module.keycloak.db_credentials_secret_id
}

output "cost_warning" {
  description = "Cost optimization recommendations"
  value       = module.keycloak.cost_warning
}
