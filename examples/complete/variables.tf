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

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "RDS storage in GB"
  type        = number
  default     = 20
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
