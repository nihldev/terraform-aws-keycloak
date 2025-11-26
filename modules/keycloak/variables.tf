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

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarm notifications. If not provided, alarms will not send notifications."
  type        = string
  default     = ""
}

variable "health_check_grace_period_seconds" {
  description = "Health check grace period for ECS service (600 recommended for initial deployments)"
  type        = number
  default     = 600
}

variable "health_check_path" {
  description = "Health check path for ALB target group. Default is Keycloak's standard health endpoint."
  type        = string
  default     = "/health/ready"
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of tasks for autoscaling (defaults to desired_count * 3 if not set)"
  type        = number
  default     = null
}

#######################
# Database Configuration
#######################

variable "database_type" {
  description = <<-EOT
    Database type: rds, aurora, or aurora-serverless.

    - rds: Standard RDS PostgreSQL (cost-effective, good for most workloads)
    - aurora: Aurora Provisioned (better HA, up to 15 read replicas, faster failover)
    - aurora-serverless: Aurora Serverless v2 (auto-scaling, ideal for variable workloads)
  EOT
  type        = string
  default     = "rds"

  validation {
    condition     = contains(["rds", "aurora", "aurora-serverless"], var.database_type)
    error_message = "Database type must be one of: rds, aurora, aurora-serverless"
  }
}

variable "db_instance_class" {
  description = <<-EOT
    Database instance class for RDS and Aurora Provisioned.
    Examples: db.t4g.micro, db.t4g.small, db.r6g.large

    Ignored when database_type = "aurora-serverless" (use db_capacity_min/max instead).
  EOT
  type        = string
  default     = "db.t4g.micro"
}

variable "db_capacity_min" {
  description = <<-EOT
    Minimum capacity for Aurora Serverless v2 in ACUs (Aurora Capacity Units).
    Only used when database_type = "aurora-serverless".
    Range: 0.5 to 128 ACUs (1 ACU ≈ 2GB RAM)

    Examples:
    - 0.5: Minimal cost for dev/test
    - 2: Light production workload
    - 8: Medium production workload
  EOT
  type        = number
  default     = 0.5

  validation {
    condition     = var.db_capacity_min >= 0.5 && var.db_capacity_min <= 128
    error_message = "Aurora Serverless min capacity must be between 0.5 and 128 ACUs"
  }
}

variable "db_capacity_max" {
  description = <<-EOT
    Maximum capacity for Aurora Serverless v2 in ACUs.
    Only used when database_type = "aurora-serverless".
    Must be >= db_capacity_min.
  EOT
  type        = number
  default     = 2

  validation {
    condition     = var.db_capacity_max >= 0.5 && var.db_capacity_max <= 128
    error_message = "Aurora Serverless max capacity must be between 0.5 and 128 ACUs"
  }

  validation {
    condition     = var.db_capacity_max >= var.db_capacity_min
    error_message = "Aurora Serverless max capacity must be >= min capacity"
  }
}

variable "aurora_replica_count" {
  description = <<-EOT
    Number of Aurora read replicas (0-15).
    Only applies when database_type = "aurora".

    If null (default), automatically creates:
    - 1 replica when multi_az = true
    - 0 replicas when multi_az = false

    Set explicitly to override automatic behavior.
  EOT
  type        = number
  default     = null

  validation {
    condition = (
      var.aurora_replica_count == null ||
      (var.aurora_replica_count >= 0 && var.aurora_replica_count <= 15)
    )
    error_message = "Aurora replica count must be null or between 0 and 15"
  }
}

variable "aurora_backtrack_window" {
  description = <<-EOT
    Hours to retain backtrack data for Aurora Provisioned (0-72).
    Allows rewinding database to any point in time without restore from backup.
    Only applies when database_type = "aurora".

    If null (default), automatically sets:
    - 24 hours for prod environment
    - 0 hours (disabled) for non-prod

    Cost: ~$0.012 per million change records/month (typically minimal)
  EOT
  type        = number
  default     = null

  validation {
    condition = (
      var.aurora_backtrack_window == null ||
      (var.aurora_backtrack_window >= 0 && var.aurora_backtrack_window <= 72)
    )
    error_message = "Aurora backtrack window must be null or between 0 and 72 hours"
  }
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

  validation {
    condition     = var.db_backup_retention_period >= 7
    error_message = "Backup retention period must be at least 7 days to ensure adequate data protection and recovery capabilities."
  }
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
  description = <<-EOT
    Performance Insights retention period in days.

    If null (default), automatically sets:
    - 31 days for Aurora in prod environment
    - 7 days for RDS or non-prod

    Valid values: 7, 31, 62, 93, 124, 155, 186, 217, 248, 279, 310, 341, 372,
    403, 434, 465, 496, 527, 558, 589, 620, 651, 682, 713, 731
  EOT
  type        = number
  default     = null

  validation {
    condition = (
      var.db_performance_insights_retention_period == null ||
      contains([
        7, 31, 62, 93, 124, 155, 186, 217, 248, 279, 310, 341, 372, 403,
        434, 465, 496, 527, 558, 589, 620, 651, 682, 713, 731
      ], var.db_performance_insights_retention_period)
    )
    error_message = "Performance Insights retention must be null or one of the valid retention periods"
  }
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

#######################
# SES Email Configuration
#######################

variable "enable_ses" {
  description = <<-EOT
    Enable SES integration for Keycloak email functionality.
    When enabled, creates:
    - SES domain identity with DKIM
    - IAM user for SMTP credentials
    - Secrets Manager secret with SMTP configuration

    Note: SES starts in sandbox mode. You must request production access
    to send emails to non-verified addresses.
  EOT
  type        = bool
  default     = false
}

variable "ses_domain" {
  description = <<-EOT
    Domain to use for sending emails via SES.
    This domain will be verified with SES and DKIM will be configured.
    Required if enable_ses = true.
    Example: "example.com" or "mail.example.com"
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.enable_ses == false || var.ses_domain != ""
    error_message = "ses_domain is required when enable_ses is true."
  }
}

variable "ses_email_identity" {
  description = <<-EOT
    Optional: Specific email address to verify instead of (or in addition to) domain.
    Useful for testing in SES sandbox mode without domain verification.
    Example: "noreply@example.com"
  EOT
  type        = string
  default     = ""
}

variable "ses_from_email" {
  description = <<-EOT
    Email address to use as the 'From' address for Keycloak emails.
    Must be from the verified domain or verified email identity.
    Defaults to "noreply@{ses_domain}" if not specified.
    Example: "keycloak@example.com" or "noreply@example.com"
  EOT
  type        = string
  default     = ""
}

variable "ses_route53_zone_id" {
  description = <<-EOT
    Route53 hosted zone ID for automatic DNS record creation.
    If provided, the module will automatically create:
    - TXT record for domain verification
    - CNAME records for DKIM

    If not provided, you must manually create these DNS records.
    The required records will be available in the outputs.
  EOT
  type        = string
  default     = ""
}

variable "ses_configuration_set_enabled" {
  description = <<-EOT
    Enable SES Configuration Set for email tracking and metrics.
    Creates CloudWatch metrics for:
    - Send, reject, bounce, complaint events
    - Delivery, open, click tracking

    Useful for monitoring email deliverability.
  EOT
  type        = bool
  default     = false
}

#######################
# Custom Image / ECR Configuration
#######################

variable "keycloak_image" {
  description = <<-EOT
    Custom Keycloak Docker image URI.
    Use this to deploy a custom Keycloak image with themes, providers, or extensions.

    Examples:
    - ECR: "123456789.dkr.ecr.us-east-1.amazonaws.com/keycloak:v1.0.0"
    - Docker Hub: "myorg/keycloak-custom:latest"

    If empty (default), uses the official Keycloak image from quay.io.

    To use ECR: Set this to the ECR repository URL from the module output,
    e.g., keycloak_image = module.keycloak.ecr_repository_url
  EOT
  type        = string
  default     = ""
}

variable "create_ecr_repository" {
  description = <<-EOT
    Create an ECR repository for custom Keycloak images.
    When enabled, the module creates:
    - ECR repository with image scanning
    - Lifecycle policy to manage image retention
    - Repository URL output for pushing images

    Note: This only creates the repository. To use it:
    1. Apply to create the ECR repository
    2. Build and push your custom image to the repository
    3. Set keycloak_image to the ECR URL (available as ecr_repository_url output)
  EOT
  type        = bool
  default     = false
}

variable "ecr_image_tag_mutability" {
  description = <<-EOT
    Image tag mutability setting for ECR repository.
    - MUTABLE: Tags can be overwritten (convenient for dev)
    - IMMUTABLE: Tags cannot be overwritten (recommended for prod)
  EOT
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.ecr_image_tag_mutability)
    error_message = "ecr_image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "ecr_scan_on_push" {
  description = "Enable vulnerability scanning when images are pushed to ECR"
  type        = bool
  default     = true
}

variable "ecr_image_retention_count" {
  description = "Number of tagged images to retain in ECR (older images are deleted)"
  type        = number
  default     = 30
}

variable "ecr_kms_key_id" {
  description = <<-EOT
    KMS key ID for ECR image encryption.
    If empty, uses default AES256 encryption.
    If provided, uses KMS encryption with the specified key.
  EOT
  type        = string
  default     = ""
}

variable "ecr_allowed_account_ids" {
  description = <<-EOT
    List of AWS account IDs allowed to pull images from this ECR repository.
    Useful for cross-account deployments.
    Leave empty for same-account only access.
  EOT
  type        = list(string)
  default     = []
}
