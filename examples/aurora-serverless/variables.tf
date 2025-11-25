variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "keycloak"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "multi_az" {
  description = "Enable multi-AZ deployment"
  type        = bool
  default     = false # Single AZ for dev by default
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 1 # Single task for dev
}

variable "keycloak_version" {
  description = "Keycloak version to deploy"
  type        = string
  default     = "26.0"
}

variable "task_cpu" {
  description = "CPU units for ECS task (1024 = 1 vCPU)"
  type        = number
  default     = 512 # Smaller for dev
}

variable "task_memory" {
  description = "Memory for ECS task in MB"
  type        = number
  default     = 1024 # Smaller for dev
}

variable "db_capacity_min" {
  description = "Minimum Aurora Serverless v2 capacity (ACUs). 0.5 is the minimum."
  type        = number
  default     = 0.5 # Minimum for cost optimization
}

variable "db_capacity_max" {
  description = "Maximum Aurora Serverless v2 capacity (ACUs). Scales up to this value under load."
  type        = number
  default     = 2 # Conservative max for dev/staging
}

variable "db_performance_insights_retention_period" {
  description = "Performance Insights retention in days (null = auto: 7 days for serverless)"
  type        = number
  default     = null
}

variable "db_backup_retention_period" {
  description = "Database backup retention period in days"
  type        = number
  default     = 7
}

variable "keycloak_hostname" {
  description = "Hostname for Keycloak (required if using HTTPS)"
  type        = string
  default     = ""
}

variable "keycloak_loglevel" {
  description = "Keycloak log level"
  type        = string
  default     = "INFO"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS (optional)"
  type        = string
  default     = ""
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Keycloak"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
