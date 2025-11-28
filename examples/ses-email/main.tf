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
# VPC (Minimal for testing)
#######################

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.name}-vpc-${var.environment}"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

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
# Keycloak Module with SES Email Integration
#######################

module "keycloak" {
  source = "../../modules/keycloak"

  name        = var.name
  environment = var.environment

  # Networking
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnets
  private_subnet_ids = module.vpc.private_subnets

  # Minimal configuration for testing
  multi_az      = false
  desired_count = 1
  task_cpu      = 512
  task_memory   = 1024

  # Database: Smallest instance
  db_instance_class          = "db.t4g.micro"
  db_allocated_storage       = 20
  db_backup_retention_period = 7

  # SES Email Configuration
  enable_ses                    = var.enable_ses
  ses_domain                    = var.ses_domain
  ses_email_identity            = var.ses_email_identity
  ses_from_email                = var.ses_from_email
  ses_route53_zone_id           = var.ses_route53_zone_id
  ses_configuration_set_enabled = var.ses_configuration_set_enabled

  # Basic security
  allowed_cidr_blocks = var.allowed_cidr_blocks

  tags = {
    Project     = var.name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Test        = "SES-Email"
  }
}
