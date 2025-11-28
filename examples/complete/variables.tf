variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "multi_az" {
  description = "Enable multi-AZ deployment"
  type        = bool
  default     = false
}

variable "desired_count" {
  description = "Number of Keycloak tasks"
  type        = number
  default     = 2
}

variable "keycloak_version" {
  description = "Keycloak version"
  type        = string
  default     = "26.0"
}

variable "task_cpu" {
  description = "CPU units for task"
  type        = number
  default     = 1024
}

variable "task_memory" {
  description = "Memory for task in MB"
  type        = number
  default     = 2048
}

variable "database_type" {
  description = "Database type: rds, aurora, or aurora-serverless"
  type        = string
  default     = "rds"
}

variable "db_instance_class" {
  description = "Database instance class (for RDS or Aurora Provisioned)"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "RDS storage in GB (RDS only)"
  type        = number
  default     = 20
}

variable "db_capacity_min" {
  description = "Minimum Aurora Serverless v2 capacity in ACUs (aurora-serverless only)"
  type        = number
  default     = 0.5
}

variable "db_capacity_max" {
  description = "Maximum Aurora Serverless v2 capacity in ACUs (aurora-serverless only)"
  type        = number
  default     = 2
}

variable "aurora_replica_count" {
  description = "Number of Aurora read replicas (aurora only, null = auto based on multi_az)"
  type        = number
  default     = null
}

variable "aurora_backtrack_window" {
  description = "Aurora backtrack window in hours (aurora only, null = auto: 24h prod, 0 non-prod)"
  type        = number
  default     = null
}

variable "db_performance_insights_retention_period" {
  description = "Performance Insights retention in days (null = auto based on database type)"
  type        = number
  default     = null
}

variable "db_backup_retention_period" {
  description = "Backup retention in days"
  type        = number
  default     = 7
}

variable "keycloak_hostname" {
  description = "Keycloak hostname"
  type        = string
  default     = ""
}

variable "keycloak_loglevel" {
  description = "Keycloak log level"
  type        = string
  default     = "INFO"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = ""
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Keycloak"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
