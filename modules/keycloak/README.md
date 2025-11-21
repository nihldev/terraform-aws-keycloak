# Keycloak Terraform Module

This module deploys Keycloak on AWS using ECS Fargate, RDS PostgreSQL, and Application Load Balancer.

## Features

- **ECS Fargate**: Serverless container deployment with auto-scaling
- **RDS PostgreSQL**: Managed database with automated backups
- **High Availability**: Optional multi-AZ deployment
- **Security**:
  - Secrets stored in AWS Secrets Manager
  - Security groups with least-privilege access
  - Encrypted RDS storage
  - HTTPS support with ACM certificates
- **Monitoring**:
  - CloudWatch logs and metrics
  - Pre-configured alarms for CPU, memory, and health
  - Container Insights support
- **Auto-scaling**: Automatic scaling based on CPU and memory utilization
- **Production-ready**: Circuit breaker, health checks, and deployment safeguards

## Requirements

- Terraform >= 1.14.0
- AWS Provider ~> 5.0
- Existing VPC with public and private subnets (see Network Prerequisites below)
- (Optional) ACM certificate for HTTPS

### Network Prerequisites

Your VPC must have the following configuration:

**Subnets:**
- **Public subnets** (for ALB):
  - Minimum 2 subnets (3 recommended for production)
  - Must be in different Availability Zones
  - Must have internet gateway attached
  - Route table with `0.0.0.0/0` → Internet Gateway
- **Private subnets** (for ECS and RDS):
  - Minimum 2 subnets (3 recommended for production)
  - Must be in different Availability Zones
  - Must have NAT Gateway for outbound internet access
  - Route table with `0.0.0.0/0` → NAT Gateway

**NAT Gateway:**
- Required for ECS tasks to:
  - Pull container images from quay.io
  - Connect to external identity providers
  - Perform software updates
- Can use single NAT Gateway for dev (cost savings)
- Should use one NAT Gateway per AZ for production (high availability)

**Subnet Sizing:**
- Public subnets: `/24` (256 IPs) - sufficient for ALBs
- Private subnets: `/22` or larger recommended
  - Each ECS task needs an IP address
  - Each RDS instance needs an IP address
  - Example: `/22` = 1,024 IPs

**DNS:**
- `enable_dns_hostnames = true`
- `enable_dns_support = true`

**Example VPC Setup:**
```
VPC: 10.0.0.0/16
├── Public Subnets (ALB):
│   ├── 10.0.101.0/24 (us-east-1a)
│   ├── 10.0.102.0/24 (us-east-1b)
│   └── 10.0.103.0/24 (us-east-1c)
├── Private Subnets (ECS + RDS):
│   ├── 10.0.1.0/22 (us-east-1a) - 1,024 IPs
│   ├── 10.0.5.0/22 (us-east-1b) - 1,024 IPs
│   └── 10.0.9.0/22 (us-east-1c) - 1,024 IPs
└── NAT Gateways:
    ├── NAT-GW in us-east-1a (or single NAT for dev)
    ├── NAT-GW in us-east-1b (production)
    └── NAT-GW in us-east-1c (production)
```

## Architecture

```text
Internet → ALB (Public Subnets) → ECS Fargate (Private Subnets) → RDS PostgreSQL (Private Subnets)
```

## Usage

### Basic Example (Development)

```hcl
module "keycloak" {
  source = "./modules/keycloak"

  name        = "myapp"
  environment = "dev"

  # Networking
  vpc_id             = "vpc-xxxxx"
  public_subnet_ids  = ["subnet-xxxxx", "subnet-yyyyy"]
  private_subnet_ids = ["subnet-aaaaa", "subnet-bbbbb"]

  # Basic configuration for development
  multi_az       = false
  desired_count  = 1

  tags = {
    Project = "MyApp"
    Team    = "Platform"
  }
}
```

### Production Example

```hcl
module "keycloak" {
  source = "./modules/keycloak"

  name        = "myapp"
  environment = "prod"

  # Networking
  vpc_id             = "vpc-xxxxx"
  public_subnet_ids  = ["subnet-xxxxx", "subnet-yyyyy", "subnet-zzzzz"]
  private_subnet_ids = ["subnet-aaaaa", "subnet-bbbbb", "subnet-ccccc"]

  # HTTPS with custom domain
  certificate_arn    = "arn:aws:acm:us-east-1:xxxxx:certificate/xxxxx"
  keycloak_hostname  = "auth.example.com"

  # High availability
  multi_az      = true
  desired_count = 3

  # Enhanced capacity
  task_cpu    = 2048
  task_memory = 4096

  # Production database
  db_instance_class          = "db.r6g.large"
  db_allocated_storage       = 100
  db_backup_retention_period = 30
  db_deletion_protection     = true

  tags = {
    Project     = "MyApp"
    Team        = "Platform"
    Environment = "Production"
  }
}
```

### With Custom Domain (Route53)

```hcl
# Request ACM certificate
resource "aws_acm_certificate" "keycloak" {
  domain_name       = "auth.example.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Create Route53 record for validation
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.keycloak.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = var.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

# Wait for certificate validation
resource "aws_acm_certificate_validation" "keycloak" {
  certificate_arn         = aws_acm_certificate.keycloak.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Deploy Keycloak
module "keycloak" {
  source = "./modules/keycloak"

  name        = "myapp"
  environment = "prod"

  vpc_id             = var.vpc_id
  public_subnet_ids  = var.public_subnet_ids
  private_subnet_ids = var.private_subnet_ids

  certificate_arn   = aws_acm_certificate.keycloak.arn
  keycloak_hostname = "auth.example.com"

  multi_az      = true
  desired_count = 2
}

# Create DNS record pointing to ALB
resource "aws_route53_record" "keycloak" {
  zone_id = var.route53_zone_id
  name    = "auth.example.com"
  type    = "A"

  alias {
    name                   = module.keycloak.alb_dns_name
    zone_id                = module.keycloak.alb_zone_id
    evaluate_target_health = true
  }
}
```

## Accessing Keycloak

After deployment:

1. Get the Keycloak URL from outputs:

   ```bash
   Terraform output keycloak_url
   ```

2. Get admin credentials from Secrets Manager:

   ```bash
   AWS secretsmanager get-secret-value \
     --secret-id $(Terraform output -raw admin_credentials_secret_arn) \
     --query SecretString \
     --output text | jq -r '.username, .password'
   ```

3. Access the admin console at `https://your-domain/admin` or `http://alb-dns/admin`

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | -------- |
| name | Name prefix for all resources | string | - | yes |
| environment | Environment name (e.g., dev, staging, prod) | string | - | yes |
| vpc_id | VPC ID where resources will be created | string | - | yes |
| public_subnet_ids | Public subnet IDs for ALB | list(string) | - | yes |
| private_subnet_ids | Private subnet IDs for ECS and RDS | list(string) | - | yes |
| allowed_cidr_blocks | CIDR blocks allowed to access Keycloak | list(string) | ["0.0.0.0/0"] | no |
| certificate_arn | ACM certificate ARN for HTTPS | string | "" | no |
| multi_az | Enable multi-AZ deployment | bool | false | no |
| Keycloak_version | Keycloak version to deploy | string | "26.0" | no |
| desired_count | Number of Keycloak tasks | number | 2 | no |
| task_cpu | CPU units for task (1024 = 1 vCPU) | number | 1024 | no |
| task_memory | Memory for task in MB | number | 2048 | no |
| db_instance_class | RDS instance class | string | "db.t4g.micro" | no |
| db_allocated_storage | RDS storage in GB | number | 20 | no |
| db_engine_version | PostgreSQL version | string | "16.3" | no |
| db_backup_retention_period | Backup retention in days | number | 7 | no |
| db_deletion_protection | Enable deletion protection | bool | true | no |
| Keycloak_hostname | Keycloak hostname (required for production) | string | "" | no |
| Keycloak_loglevel | Log level (INFO, DEBUG, WARN, ERROR) | string | "INFO" | no |
| tags | Additional tags for resources | map(string) | {} | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| Keycloak_url | URL to access Keycloak |
| Keycloak_admin_console_url | URL to access admin console |
| alb_dns_name | DNS name of the ALB |
| alb_zone_id | Zone ID for Route53 alias records |
| db_credentials_secret_arn | ARN of database credentials secret |
| admin_credentials_secret_arn | ARN of admin credentials secret |
| ECS_cluster_name | Name of the ECS cluster |
| cloudwatch_log_group_name | Name of the CloudWatch log group |

## Cost Optimization

### Development/Testing

```hcl
multi_az                   = false
desired_count              = 1
task_cpu                   = 512
task_memory                = 1024
db_instance_class          = "db.t4g.micro"
db_backup_retention_period = 1
```

Estimated cost: ~$50-80/month

### Production

```hcl
multi_az                   = true
desired_count              = 3
task_cpu                   = 1024
task_memory                = 2048
db_instance_class          = "db.r6g.large"
db_backup_retention_period = 30
```

Estimated cost: ~$300-500/month (varies by region and usage)

## Security Considerations

1. **Network Security**: Deploy in private subnets, use security groups with minimal access
2. **Secrets**: All credentials stored in Secrets Manager, never in code
3. **Encryption**: RDS storage encrypted at rest
4. **HTTPS**: Always use ACM certificates for production
5. **Access Control**: Restrict `allowed_cidr_blocks` to known IP ranges
6. **Deletion Protection**: Enabled by default for RDS in production

## Monitoring

The module creates CloudWatch alarms for:

- High CPU utilization (ECS & RDS)
- High memory utilization (ECS)
- Unhealthy targets
- Low storage space (RDS)

View logs:

```bash
AWS logs tail /ECS/myapp-Keycloak-prod --follow
```

## Scaling

The module automatically scales ECS tasks based on:

- CPU utilization (target: 70%)
- Memory utilization (target: 70%)

Limits:

- Min: `desired_count`
- Max: `desired_count * 3`

## Maintenance

### Database Maintenance

- Automated backups during maintenance window
- Default window: Sunday 04:00-05:00 UTC
- Customize with `db_maintenance_window` variable

### Keycloak Updates

Update the `keycloak_version` variable and apply:

```bash
Terraform apply -var="keycloak_version=26.1"
```

ECS will perform a rolling update with circuit breaker protection.

## Troubleshooting

### Tasks not starting

1. Check ECS service events:

   ```bash
   AWS ECS describe-services --cluster <cluster-name> --services <service-name>
   ```

2. Check CloudWatch logs for errors
3. Verify database connectivity from ECS security group

### Health check failures

- Keycloak takes 1-2 minutes to start
- Check logs for database connection errors
- Verify database credentials in Secrets Manager

### High costs

- Reduce `desired_count` for dev/test environments
- Use smaller instance types (`db.t4g.micro`, `task_cpu=512`)
- Disable multi-AZ for non-production

## License

This module is provided as-is under the MIT License.
