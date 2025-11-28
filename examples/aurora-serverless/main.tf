terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

#######################
# VPC (Example - use your existing VPC in production)
#######################

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.name}-vpc-${var.environment}"
  cidr = "10.0.0.0/16"

  # 2 AZs minimum for Aurora Serverless v2
  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # Single NAT Gateway for cost optimization (serverless is often dev/staging)
  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.name}-vpc-${var.environment}"
    Environment = var.environment
    Project     = var.name
  }
}

#######################
# Keycloak Module with Aurora Serverless v2
#######################

module "keycloak" {
  source = "../../modules/keycloak"

  name        = var.name
  environment = var.environment

  # Networking
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnets
  private_subnet_ids = module.vpc.private_subnets

  # Single instance for dev/staging (scale as needed)
  multi_az      = var.multi_az
  desired_count = var.desired_count

  # ECS configuration
  keycloak_version = var.keycloak_version
  task_cpu         = var.task_cpu
  task_memory      = var.task_memory

  # Aurora Serverless v2 configuration
  database_type   = "aurora-serverless"
  db_capacity_min = var.db_capacity_min # Minimum ACUs (0.5 = smallest)
  db_capacity_max = var.db_capacity_max # Maximum ACUs (scales up to this)

  # Performance Insights retention
  db_performance_insights_retention_period = var.db_performance_insights_retention_period

  # Backup configuration
  db_backup_retention_period = var.db_backup_retention_period

  # Keycloak configuration
  keycloak_hostname = var.keycloak_hostname
  keycloak_loglevel = var.keycloak_loglevel

  # HTTPS (optional)
  certificate_arn = var.certificate_arn

  # Security
  allowed_cidr_blocks = var.allowed_cidr_blocks

  tags = {
    Project      = var.name
    Environment  = var.environment
    ManagedBy    = "Terraform"
    DatabaseType = "aurora-serverless-v2"
  }
}
