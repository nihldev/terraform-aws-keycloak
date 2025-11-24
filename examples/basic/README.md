# Basic Keycloak Deployment Example

This example demonstrates a minimal Keycloak deployment suitable for development and testing.

## Features

- **Minimal Configuration**: Single instance, smallest resources
- **Fast Deployment**: ~15-20 minutes
- **Cost Optimized**: Single NAT Gateway, small instance types
- **2 Availability Zones**: Basic redundancy for ALB and RDS

## What This Example Deploys

- VPC with 2 AZs (public + private subnets)
- Single NAT Gateway
- ECS Fargate cluster with 1 Keycloak task (512 CPU, 1GB RAM)
- RDS PostgreSQL db.t4g.micro instance
- Application Load Balancer (HTTP only)
- CloudWatch logs and basic monitoring

## Usage

```bash
cd examples/basic

# Initialize
Terraform init

# Plan
Terraform plan

# Apply
Terraform apply

# Get outputs
Terraform output keycloak_url
Terraform output admin_credentials_secret_id
```

## Accessing Keycloak

```bash
# Get Keycloak URL
KEYCLOAK_URL=$(Terraform output -raw keycloak_url)
echo "Keycloak: $KEYCLOAK_URL"

# Get admin credentials
SECRET_ID=$(Terraform output -raw admin_credentials_secret_id)
AWS secretsmanager get-secret-value \
  --secret-id "$SECRET_ID" \
  --query SecretString \
  --output text | jq -r '"Username: \(.username)\nPassword: \(.password)"'
```

## Cost Estimate

Approximately $50-70/month (us-east-1):

- ECS Fargate (1 task): ~$10/month
- RDS db.t4g.micro: ~$15/month
- ALB: ~$20/month
- NAT Gateway: ~$35/month

## Cleanup

```bash
Terraform destroy
```

## Notes

- **Not for production**: This example uses minimal resources
- **HTTP only**: No HTTPS certificate configured
- **Single instance**: No high availability
- **Public access**: Allows 0.0.0.0/0 (restrict this in production)
