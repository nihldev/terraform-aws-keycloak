variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "keycloak-test"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "test"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access Keycloak"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
