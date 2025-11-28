#######################
# Keycloak Module
#######################
#
# This module deploys Keycloak (an open-source identity and access management solution)
# on AWS using ECS Fargate with an Application Load Balancer and RDS PostgreSQL database.
#
# Key Features:
# - ECS Fargate deployment with auto-scaling
# - Application Load Balancer with optional HTTPS
# - RDS PostgreSQL database with automated backups
# - Secrets Manager for secure credential storage
# - CloudWatch logging and monitoring
# - Multi-AZ support for high availability
#
# Resources are organized across multiple files:
# - ecs.tf: ECS cluster, task definition, service, and auto-scaling
# - networking.tf: ALB, security groups, and listeners
# - rds.tf: PostgreSQL database and security
# - iam.tf: IAM roles and policies
# - cloudwatch.tf: Log groups and monitoring
# - variables.tf: Input variables
# - outputs.tf: Output values
# - versions.tf: Terraform and provider version constraints
