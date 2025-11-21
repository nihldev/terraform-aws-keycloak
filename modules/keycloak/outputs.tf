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
# RDS Outputs
#######################

output "db_instance_id" {
  description = "ID of the RDS instance"
  value       = aws_db_instance.keycloak.id
}

output "db_instance_address" {
  description = "Address of the RDS instance"
  value       = aws_db_instance.keycloak.address
}

output "db_instance_endpoint" {
  description = "Connection endpoint for the RDS instance"
  value       = aws_db_instance.keycloak.endpoint
}

output "db_instance_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.keycloak.arn
}

output "db_name" {
  description = "Name of the database"
  value       = aws_db_instance.keycloak.db_name
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
