#######################
# General Configuration
#######################

variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}

#######################
# Networking
#######################

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks and RDS"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for Application Load Balancer"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Keycloak through ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = !(
      var.environment == "prod" &&
      contains(var.allowed_cidr_blocks, "0.0.0.0/0")
    )
    error_message = <<-EOT
      SECURITY WARNING: Production environment detected with unrestricted access (0.0.0.0/0).

      Restrict access to specific CIDR blocks for security:
      - Office IP ranges: ["203.0.113.0/24"]
      - VPN CIDR blocks: ["198.51.100.0/24"]
      - CloudFront IP ranges (if using CDN)
      - Partner/customer IP ranges

      Example: allowed_cidr_blocks = ["203.0.113.0/24", "198.51.100.0/24"]

      If you truly need public access, set environment to something other than "prod" or implement additional security controls (WAF, rate limiting, MFA).
    EOT
  }
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener (optional, will create HTTP listener if not provided)"
  type        = string
  default     = ""
}

variable "alb_access_logs_enabled" {
  description = "Enable ALB access logs"
  type        = bool
  default     = false
}

variable "alb_access_logs_bucket" {
  description = "S3 bucket name for ALB access logs (required if alb_access_logs_enabled is true)"
  type        = string
  default     = ""
}

variable "alb_access_logs_prefix" {
  description = "S3 bucket prefix for ALB access logs"
  type        = string
  default     = ""
}

#######################
# High Availability
#######################

variable "multi_az" {
  description = "Enable multi-AZ deployment for high availability"
  type        = bool
  default     = false
}

#######################
# ECS Configuration
#######################

variable "keycloak_version" {
  description = "Keycloak version to deploy"
  type        = string
  default     = "26.0"
}

variable "desired_count" {
  description = "Number of Keycloak tasks to run"
  type        = number
  default     = 2
}

variable "task_cpu" {
  description = "CPU units for Keycloak task (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "task_memory" {
  description = "Memory for Keycloak task in MB"
  type        = number
  default     = 2048
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for ECS cluster"
  type        = bool
  default     = true
}

variable "health_check_grace_period_seconds" {
  description = "Health check grace period for ECS service"
  type        = number
  default     = 300
}

#######################
# RDS Configuration
#######################

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for RDS autoscaling in GB"
  type        = number
  default     = 100
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.3"
}

variable "db_backup_retention_period" {
  description = "Number of days to retain RDS backups"
  type        = number
  default     = 7
}

variable "db_backup_window" {
  description = "Preferred backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "db_maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "db_deletion_protection" {
  description = "Enable deletion protection for RDS"
  type        = bool
  default     = true
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot when destroying RDS instance"
  type        = bool
  default     = false
}

variable "db_kms_key_id" {
  description = "KMS key ID for RDS encryption (uses AWS managed key if not provided)"
  type        = string
  default     = ""
}

variable "db_performance_insights_retention_period" {
  description = "Performance Insights retention period in days (7-731)"
  type        = number
  default     = 7
}

variable "db_iam_database_authentication_enabled" {
  description = "Enable IAM database authentication for RDS"
  type        = bool
  default     = false
}

variable "secrets_kms_key_id" {
  description = "KMS key ID for Secrets Manager encryption (uses AWS managed key if not provided)"
  type        = string
  default     = ""
}

#######################
# Keycloak Configuration
#######################

variable "keycloak_admin_username" {
  description = "Keycloak admin username"
  type        = string
  default     = "admin"
}

variable "keycloak_loglevel" {
  description = "Keycloak log level (INFO, DEBUG, WARN, ERROR)"
  type        = string
  default     = "INFO"
}

variable "keycloak_hostname" {
  description = "Keycloak hostname (required for production deployments)"
  type        = string
  default     = ""
}

variable "keycloak_extra_env_vars" {
  description = "Additional environment variables for Keycloak container"
  type        = map(string)
  default     = {}
}

variable "keycloak_cache_enabled" {
  description = "Enable distributed cache for multi-instance deployments (required when desired_count > 1)"
  type        = bool
  default     = true
}

variable "keycloak_cache_stack" {
  description = "Cache stack protocol (tcp, udp, kubernetes, jdbc-ping). Use 'jdbc-ping' for reliable ECS deployments"
  type        = string
  default     = "jdbc-ping"

  validation {
    condition     = contains(["tcp", "udp", "jdbc-ping"], var.keycloak_cache_stack)
    error_message = "Cache stack must be one of: tcp, udp, jdbc-ping. For ECS deployments, use 'jdbc-ping'."
  }
}

variable "db_pool_initial_size" {
  description = "Initial size of database connection pool"
  type        = number
  default     = 5
}

variable "db_pool_min_size" {
  description = "Minimum size of database connection pool"
  type        = number
  default     = 5
}

variable "db_pool_max_size" {
  description = "Maximum size of database connection pool"
  type        = number
  default     = 20
}
