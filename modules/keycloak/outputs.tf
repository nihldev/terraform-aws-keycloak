#######################
# Load Balancer Outputs
#######################

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.keycloak.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer (for Route53 alias records)"
  value       = aws_lb.keycloak.zone_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.keycloak.arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.keycloak.arn
}

#######################
# ECS Outputs
#######################

output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.keycloak.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.keycloak.name
}

output "ecs_service_id" {
  description = "ID of the ECS service"
  value       = aws_ecs_service.keycloak.id
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.keycloak.name
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.keycloak.arn
}

#######################
# Database Outputs
#######################

output "database_type" {
  description = "Type of database deployed (rds, aurora, or aurora-serverless)"
  value       = var.database_type
}

output "db_instance_id" {
  description = "ID of the database instance or cluster"
  value       = var.database_type == "rds" ? aws_db_instance.keycloak[0].id : aws_rds_cluster.keycloak[0].id
}

output "db_instance_address" {
  description = "Address of the database endpoint"
  value       = var.database_type == "rds" ? aws_db_instance.keycloak[0].address : aws_rds_cluster.keycloak[0].endpoint
}

output "db_instance_endpoint" {
  description = "Connection endpoint for the database"
  value       = var.database_type == "rds" ? aws_db_instance.keycloak[0].endpoint : "${aws_rds_cluster.keycloak[0].endpoint}:${aws_rds_cluster.keycloak[0].port}"
}

output "db_instance_arn" {
  description = "ARN of the database instance or cluster"
  value       = var.database_type == "rds" ? aws_db_instance.keycloak[0].arn : aws_rds_cluster.keycloak[0].arn
}

output "db_name" {
  description = "Name of the database"
  value       = "keycloak"
}

output "db_reader_endpoint" {
  description = "Reader endpoint for Aurora cluster (empty for RDS)"
  value       = var.database_type != "rds" ? aws_rds_cluster.keycloak[0].reader_endpoint : ""
}

output "cost_warning" {
  description = "Cost optimization recommendations"
  value       = local.cost_warning
}

#######################
# Secrets Manager Outputs
#######################

output "db_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  value       = aws_secretsmanager_secret.keycloak_db.arn
}

output "admin_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Keycloak admin credentials"
  value       = aws_secretsmanager_secret.keycloak_admin.arn
}

output "admin_credentials_secret_id" {
  description = "Secret ID for retrieving admin credentials (use with AWS CLI: aws secretsmanager get-secret-value --secret-id <this-value>)"
  value       = aws_secretsmanager_secret.keycloak_admin.id
}

output "db_credentials_secret_id" {
  description = "Secret ID for retrieving database credentials (use with AWS CLI: aws secretsmanager get-secret-value --secret-id <this-value>)"
  value       = aws_secretsmanager_secret.keycloak_db.id
}

#######################
# Security Group Outputs
#######################

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "ecs_tasks_security_group_id" {
  description = "ID of the ECS tasks security group"
  value       = aws_security_group.ecs_tasks.id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

#######################
# CloudWatch Outputs
#######################

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.keycloak.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.keycloak.arn
}

#######################
# Keycloak Access Information
#######################

output "keycloak_url" {
  description = "URL to access Keycloak (use this to access the admin console)"
  value       = var.certificate_arn != "" ? "https://${var.keycloak_hostname != "" ? var.keycloak_hostname : aws_lb.keycloak.dns_name}" : "http://${aws_lb.keycloak.dns_name}"
}

output "keycloak_admin_console_url" {
  description = "URL to access Keycloak admin console"
  value       = var.certificate_arn != "" ? "https://${var.keycloak_hostname != "" ? var.keycloak_hostname : aws_lb.keycloak.dns_name}/admin" : "http://${aws_lb.keycloak.dns_name}/admin"
}

#######################
# SES Email Outputs
#######################

output "ses_domain_identity_arn" {
  description = "ARN of the SES domain identity (empty if SES not enabled)"
  value       = var.enable_ses ? aws_ses_domain_identity.keycloak[0].arn : ""
}

output "ses_domain_verification_token" {
  description = "TXT record value for SES domain verification (add to DNS if not using Route53)"
  value       = var.enable_ses ? aws_ses_domain_identity.keycloak[0].verification_token : ""
}

output "ses_dkim_tokens" {
  description = "DKIM tokens for email authentication (add CNAME records to DNS if not using Route53)"
  value       = var.enable_ses ? aws_ses_domain_dkim.keycloak[0].dkim_tokens : []
}

output "ses_smtp_endpoint" {
  description = "SES SMTP endpoint for Keycloak email configuration"
  value       = var.enable_ses ? "email-smtp.${data.aws_region.current.name}.amazonaws.com" : ""
}

output "ses_smtp_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing SMTP credentials"
  value       = var.enable_ses ? aws_secretsmanager_secret.ses_smtp[0].arn : ""
}

output "ses_smtp_credentials_secret_id" {
  description = "Secret ID for retrieving SMTP credentials (use: aws secretsmanager get-secret-value --secret-id <this-value>)"
  value       = var.enable_ses ? aws_secretsmanager_secret.ses_smtp[0].id : ""
}

output "ses_from_email" {
  description = "Email address configured for sending (use in Keycloak realm settings)"
  value       = var.enable_ses ? (var.ses_from_email != "" ? var.ses_from_email : "noreply@${var.ses_domain}") : ""
}

output "ses_configuration_set_name" {
  description = "SES Configuration Set name for email tracking (empty if not enabled)"
  value       = var.enable_ses && var.ses_configuration_set_enabled ? aws_ses_configuration_set.keycloak[0].name : ""
}

output "ses_dns_records_required" {
  description = "DNS records required for SES verification (only shown if Route53 zone not provided)"
  value = var.enable_ses && var.ses_route53_zone_id == "" ? {
    verification_txt = {
      name  = "_amazonses.${var.ses_domain}"
      type  = "TXT"
      value = aws_ses_domain_identity.keycloak[0].verification_token
    }
    dkim_cnames = [
      for i, token in aws_ses_domain_dkim.keycloak[0].dkim_tokens : {
        name  = "${token}._domainkey.${var.ses_domain}"
        type  = "CNAME"
        value = "${token}.dkim.amazonses.com"
      }
    ]
  } : null
}

#######################
# ECR / Custom Image Outputs
#######################

output "keycloak_image" {
  description = "The Keycloak Docker image being used (official or custom)"
  value       = local.keycloak_image
}

output "ecr_repository_url" {
  description = "ECR repository URL for pushing custom images (empty if not created)"
  value       = var.create_ecr_repository ? aws_ecr_repository.keycloak[0].repository_url : ""
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository (empty if not created)"
  value       = var.create_ecr_repository ? aws_ecr_repository.keycloak[0].arn : ""
}

output "ecr_repository_name" {
  description = "Name of the ECR repository (empty if not created)"
  value       = var.create_ecr_repository ? aws_ecr_repository.keycloak[0].name : ""
}

output "ecr_push_commands" {
  description = "Commands to authenticate and push images to ECR"
  value = var.create_ecr_repository ? {
    login = "aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${aws_ecr_repository.keycloak[0].repository_url}"
    build = "docker build -t ${aws_ecr_repository.keycloak[0].repository_url}:latest ."
    push  = "docker push ${aws_ecr_repository.keycloak[0].repository_url}:latest"
  } : null
}
