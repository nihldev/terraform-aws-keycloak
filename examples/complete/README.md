# Complete Keycloak Deployment Example

This example demonstrates a complete Keycloak deployment with VPC creation.

## What This Example Creates

- VPC with public and private subnets across 3 availability zones
- NAT Gateway for private subnet internet access
- Keycloak deployment using the module
- All necessary networking, security, and IAM resources

## Prerequisites

- AWS account with appropriate permissions
- Terraform >= 1.14.0
- AWS CLI configured with credentials

## Usage

1. Copy the example variables file:

   ```bash
   cp Terraform.tfvars.example Terraform.tfvars
   ```

2. Edit `Terraform.tfvars` with your desired configuration

3. Initialize Terraform:

   ```bash
   Terraform init
   ```

4. Review the plan:

   ```bash
   Terraform plan
   ```

5. Apply the configuration:

   ```bash
   Terraform apply
   ```

6. Get the Keycloak URL:

   ```bash
   Terraform output keycloak_url
   ```

7. Retrieve admin credentials:

   ```bash
   Terraform output -raw get_admin_credentials_command | bash
   ```

## Configuration Examples

### Development/Testing

```hcl
name        = "myapp"
environment = "dev"
aws_region  = "us-east-1"

# Minimal resources for cost savings
multi_az              = false
desired_count         = 1
task_cpu              = 512
task_memory           = 1024
db_instance_class     = "db.t4g.micro"
db_allocated_storage  = 20
```

### Production

```hcl
name        = "myapp"
environment = "prod"
aws_region  = "us-east-1"

# High availability and performance
multi_az                   = true
desired_count              = 3
task_cpu                   = 2048
task_memory                = 4096
db_instance_class          = "db.r6g.large"
db_allocated_storage       = 100
db_backup_retention_period = 30

# HTTPS with custom domain
keycloak_hostname = "auth.example.com"
certificate_arn   = "arn:AWS:acm:us-east-1:xxxxx:certificate/xxxxx"
```

## Accessing Keycloak

After deployment completes (takes ~10-15 minutes):

1. Get the URL:

   ```bash
   Terraform output keycloak_url
   ```

2. Get admin credentials:

   ```bash
   AWS secretsmanager get-secret-value \
     --secret-id $(Terraform output -raw admin_credentials_secret_arn) \
     --query SecretString --output text | jq -r '.'
   ```

3. Open the admin console in your browser and log in

## Cost Estimate

### Development Configuration

- VPC: ~$30/month (NAT Gateway)
- ECS Fargate: ~$15/month (1 task)
- RDS: ~$15/month (db.t4g.micro)
- ALB: ~$20/month
- **Total: ~$80/month**

### Production Configuration

- VPC: ~$90/month (3 NAT Gateways for multi-AZ)
- ECS Fargate: ~$90/month (3 tasks)
- RDS: ~$200/month (db.r6g.large multi-AZ)
- ALB: ~$20/month
- **Total: ~$400/month**

## Cleanup

To destroy all resources:

```bash
Terraform destroy
```

**Note:** Ensure `db_skip_final_snapshot = true` if you want to avoid creating a final RDS snapshot.

## Customization

You can customize the deployment by modifying variables in `Terraform.tfvars`:

- Change instance sizes
- Adjust scaling parameters
- Configure different regions
- Add custom environment variables
- Restrict access with `allowed_cidr_blocks`

See `variables.tf` for all available options.

## Troubleshooting

### Deployment takes a long time

- Initial deployment takes 10-15 minutes
- RDS instance creation is the longest step (~7-10 minutes)
- ECS tasks need 2-3 minutes to become healthy

### Can't access Keycloak

- Check security group rules
- Verify `allowed_cidr_blocks` includes your IP
- Check ECS service events for task startup issues
- Review CloudWatch logs: `AWS logs tail /ECS/myapp-Keycloak-dev --follow`

### High costs

- Use `single_nat_gateway = true` in the VPC module for dev/test
- Reduce `desired_count` to 1
- Use smaller instance types
- Set `multi_az = false` for non-production environments
