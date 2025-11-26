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

output "db_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = module.keycloak.db_instance_endpoint
}

output "admin_credentials_secret_id" {
  description = "Admin credentials secret ID"
  value       = module.keycloak.admin_credentials_secret_id
}

#######################
# SES Outputs
#######################

output "ses_domain_identity_arn" {
  description = "ARN of the SES domain identity"
  value       = module.keycloak.ses_domain_identity_arn
}

output "ses_domain_verification_token" {
  description = "TXT record value for SES domain verification"
  value       = module.keycloak.ses_domain_verification_token
}

output "ses_dkim_tokens" {
  description = "DKIM tokens for email authentication"
  value       = module.keycloak.ses_dkim_tokens
}

output "ses_smtp_endpoint" {
  description = "SES SMTP endpoint"
  value       = module.keycloak.ses_smtp_endpoint
}

output "ses_smtp_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing SMTP credentials"
  value       = module.keycloak.ses_smtp_credentials_secret_arn
}

output "ses_smtp_credentials_secret_id" {
  description = "Secret ID for retrieving SMTP credentials"
  value       = module.keycloak.ses_smtp_credentials_secret_id
}

output "ses_from_email" {
  description = "Email address configured for sending"
  value       = module.keycloak.ses_from_email
}

output "ses_configuration_set_name" {
  description = "SES Configuration Set name"
  value       = module.keycloak.ses_configuration_set_name
}

output "ses_dns_records_required" {
  description = "DNS records required for SES verification"
  value       = module.keycloak.ses_dns_records_required
}
