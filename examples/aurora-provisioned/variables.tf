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
  description = "Enable multi-AZ deployment (creates Aurora read replica)"
  type        = bool
  default     = true
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 2
}

variable "keycloak_version" {
  description = "Keycloak version to deploy"
  type        = string
  default     = "26.0"
}

variable "task_cpu" {
  description = "CPU units for ECS task (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "task_memory" {
  description = "Memory for ECS task in MB"
  type        = number
  default     = 2048
}

variable "db_instance_class" {
  description = "Aurora instance class (Provisioned)"
  type        = string
  default     = "db.r6g.large" # Production-ready Aurora instance
}

variable "aurora_replica_count" {
  description = "Number of Aurora read replicas (null = auto based on multi_az)"
  type        = number
  default     = null
}

variable "aurora_backtrack_window" {
  description = "Aurora backtrack window in hours (null = auto: 24h for prod, 0 for non-prod)"
  type        = number
  default     = null
}

variable "db_performance_insights_retention_period" {
  description = "Performance Insights retention in days (null = auto: 31 for Aurora prod, 7 otherwise)"
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
