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

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Keycloak"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

#######################
# SES Configuration
#######################

variable "enable_ses" {
  description = "Enable SES email integration"
  type        = bool
  default     = true
}

variable "ses_domain" {
  description = "Domain to use for SES email sending"
  type        = string
  default     = "example.com"
}

variable "ses_email_identity" {
  description = "Specific email address to verify (optional)"
  type        = string
  default     = ""
}

variable "ses_from_email" {
  description = "Email address to use as From address"
  type        = string
  default     = ""
}

variable "ses_route53_zone_id" {
  description = "Route53 zone ID for automatic DNS record creation"
  type        = string
  default     = ""
}

variable "ses_configuration_set_enabled" {
  description = "Enable SES configuration set for email tracking"
  type        = bool
  default     = false
}
