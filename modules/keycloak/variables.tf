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

variable "alb_deletion_protection" {
  description = "Enable deletion protection for ALB (defaults to true for prod environment)"
  type        = bool
  default     = null
}

variable "waf_acl_arn" {
  description = "ARN of AWS WAF WebACL to associate with ALB (STRONGLY RECOMMENDED for production environments to protect against web exploits, DDoS, and credential stuffing attacks)"
  type        = string
  default     = ""

  validation {
    condition = !(
      var.environment == "prod" &&
      var.waf_acl_arn == ""
    )
    error_message = <<-EOT
      SECURITY WARNING: Production environment detected without WAF protection.

      Keycloak is a high-value authentication target and should be protected with AWS WAF.
      WAF provides protection against:
      - SQL injection and XSS attacks
      - DDoS and bot attacks
      - Brute force login attempts
      - Known CVE exploits

      Create a WAF WebACL and provide its ARN via waf_acl_arn variable.

      Quick setup with AWS Managed Rules:
      1. Create WAF WebACL with Core Rule Set (protects against OWASP Top 10)
      2. Add Known Bad Inputs rule set (blocks known malicious patterns)
      3. Add Rate-based rule (prevents brute force attacks)

      Example Terraform:
        resource "aws_wafv2_web_acl" "keycloak" {
          name  = "keycloak-protection"
          scope = "REGIONAL"

          default_action {
            allow {}
          }

          rule {
            name     = "AWSManagedRulesCommonRuleSet"
            priority = 1
            override_action { none {} }
            statement {
              managed_rule_group_statement {
                vendor_name = "AWS"
                name        = "AWSManagedRulesCommonRuleSet"
              }
            }
            visibility_config {
              cloudwatch_metrics_enabled = true
              metric_name                = "AWSManagedRulesCommonRuleSet"
              sampled_requests_enabled   = true
            }
          }
        }

      If you truly need to deploy without WAF, set environment to something other than "prod".
      Cost: ~$5-10/month + $0.60 per million requests - essential for production identity systems.
    EOT
  }
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

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention in days (defaults to 30 for prod, 7 for non-prod)"
  type        = number
  default     = null

  validation {
    condition = var.cloudwatch_log_retention_days == null || contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653
    ], var.cloudwatch_log_retention_days)
    error_message = "CloudWatch log retention must be one of the valid values: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653 days."
  }
}

variable "health_check_grace_period_seconds" {
  description = "Health check grace period for ECS service (600 recommended for initial deployments)"
  type        = number
  default     = 600
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of tasks for autoscaling (defaults to desired_count * 3 if not set)"
  type        = number
  default     = null
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
  description = <<-EOT
    Maximum size of database connection pool per Keycloak instance.

    IMPORTANT: Calculate total connections carefully:
    Total connections = desired_count * db_pool_max_size

    This must be LESS than your RDS max_connections setting:
    - db.t4g.micro:  ~85 connections available
    - db.t4g.small:  ~410 connections available
    - db.t4g.medium: ~820 connections available
    - db.r6g.large:  ~1000 connections available

    Examples:
    - desired_count=2, db_pool_max_size=20 → 40 total (safe for db.t4g.micro)
    - desired_count=3, db_pool_max_size=30 → 90 total (requires at least db.t4g.small)
    - desired_count=10, db_pool_max_size=20 → 200 total (requires at least db.t4g.small)

    Leave ~20% headroom for administrative connections and connection spikes.
  EOT
  type        = number
  default     = 20
}
