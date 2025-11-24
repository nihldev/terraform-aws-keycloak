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

```text
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
module "Keycloak" {
  source = "./modules/Keycloak"

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
module "Keycloak" {
  source = "./modules/Keycloak"

  name        = "myapp"
  environment = "prod"

  # Networking
  vpc_id             = "vpc-xxxxx"
  public_subnet_ids  = ["subnet-xxxxx", "subnet-yyyyy", "subnet-zzzzz"]
  private_subnet_ids = ["subnet-aaaaa", "subnet-bbbbb", "subnet-ccccc"]

  # HTTPS with custom domain
  certificate_arn    = "arn:AWS:acm:us-east-1:xxxxx:certificate/xxxxx"
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
resource "aws_acm_certificate" "Keycloak" {
  domain_name       = "auth.example.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Create Route53 record for validation
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.Keycloak.domain_validation_options : dvo.domain_name => {
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
resource "aws_acm_certificate_validation" "Keycloak" {
  certificate_arn         = aws_acm_certificate.Keycloak.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Deploy Keycloak
module "Keycloak" {
  source = "./modules/Keycloak"

  name        = "myapp"
  environment = "prod"

  vpc_id             = var.vpc_id
  public_subnet_ids  = var.public_subnet_ids
  private_subnet_ids = var.private_subnet_ids

  certificate_arn   = aws_acm_certificate.Keycloak.arn
  keycloak_hostname = "auth.example.com"

  multi_az      = true
  desired_count = 2
}

# Create DNS record pointing to ALB
resource "aws_route53_record" "Keycloak" {
  zone_id = var.route53_zone_id
  name    = "auth.example.com"
  type    = "A"

  alias {
    name                   = module.Keycloak.alb_dns_name
    zone_id                = module.Keycloak.alb_zone_id
    evaluate_target_health = true
  }
}
```

## Pre-Deployment Verification

Before running `Terraform apply`, verify your infrastructure meets these requirements:

### 1. Verify NAT Gateway Configuration

**Check NAT Gateway exists:**

```bash
# List NAT Gateways in your VPC
AWS ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=<YOUR_VPC_ID>" \
  --query 'NatGateways[*].[NatGatewayId,State,SubnetId]' \
  --output table

# Expected: At least one NAT Gateway in "available" state
```

**Verify private subnet routes to NAT Gateway:**

```bash
# Check route tables for private subnets
AWS ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=<YOUR_VPC_ID>" \
  --query 'RouteTables[*].{RouteTableId:RouteTableId,Routes:Routes[?DestinationCidrBlock==`0.0.0.0/0`].{Dest:DestinationCidrBlock,Gateway:NatGatewayId}}' \
  --output table

# Expected: Private subnet route tables show 0.0.0.0/0 -> nat-xxxxx
```

**Why this is critical:**

- ECS tasks must pull Keycloak container image from `quay.io`
- Without NAT Gateway, tasks will fail with "CannotPullContainerError"
- RDS cannot initialize without running Keycloak container

### 2. Verify Subnet Configuration

```bash
# Check subnet availability zones
AWS ec2 describe-subnets \
  --subnet-ids subnet-xxxxx subnet-yyyyy \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]' \
  --output table

# Expected: Subnets in different AZs (e.g., us-east-1a, us-east-1b)
```

### 3. Verify DNS Settings

```bash
# Check VPC DNS configuration
AWS ec2 describe-vpc-attribute \
  --vpc-id <YOUR_VPC_ID> \
  --attribute enableDnsHostnames

AWS ec2 describe-vpc-attribute \
  --vpc-id <YOUR_VPC_ID> \
  --attribute enableDnsSupport

# Expected: Both should be "true"
```

### 4. Calculate Database Connection Pool

Verify your configuration won't exceed RDS connection limits:

```bash
# Calculate: desired_count × db_pool_max_size × autoscaling_factor
# Example: 2 tasks × 20 pool × 3 (autoscaling) = 120 connections

# Check your planned configuration:
# - desired_count: 2 (default)
# - db_pool_max_size: 20 (default)
# - autoscaling_max_capacity: 6 (desired_count * 3)
# Total max connections: 6 × 20 = 120 connections

# Compare against RDS instance class limits:
# - db.t4g.micro: ~85 connections (would need adjustment!)
# - db.t4g.small: ~410 connections (safe)
```

**Action if exceeding limits:**

- Reduce `db_pool_max_size` to 10-15 for db.t4g.micro
- OR use larger RDS instance class

### 5. For Production: Create WAF WebACL

If `environment = "prod"`, you must create a WAF WebACL before deployment:

```bash
# The module will reject deployment without WAF for production
# See "Security Configuration" section for WAF setup instructions
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

## Post-Deployment Verification

After running `Terraform apply`, verify your deployment is healthy:

### 1. Check Terraform Outputs

```bash
# Verify all outputs are populated
Terraform output

# Expected outputs:
# - keycloak_url (ALB DNS or custom domain)
# - alb_dns_name
# - ecs_cluster_name
# - ecs_service_name
# - db_instance_endpoint
```

### 2. Verify ECS Service Status

**Check ECS service is running:**

```bash
# Get cluster and service names from Terraform outputs
CLUSTER_NAME=$(Terraform output -raw ecs_cluster_name)
SERVICE_NAME=$(Terraform output -raw ecs_service_name)

# Check service status
AWS ECS describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query 'services[0].{desired:desiredCount,running:runningCount,pending:pendingCount,status:status}' \
  --output table

# Expected: running == desired (e.g., 2 == 2)
# Status should be "ACTIVE"
```

**Check recent deployment events:**

```bash
# View last 5 service events
AWS ECS describe-services \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query 'services[0].events[:5].[createdAt,message]' \
  --output table

# Look for: "has reached a steady state" (success indicator)
# Avoid: "failed health checks" or "unable to pull image"
```

### 3. Verify Target Health

**Check ALB target group health:**

```bash
# Get target group ARN from Terraform outputs
TARGET_GROUP_ARN=$(Terraform output -raw target_group_arn)

# Check target health
AWS elbv2 describe-target-health \
  --target-group-arn "$TARGET_GROUP_ARN" \
  --query 'TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,Health:TargetHealth.State,Reason:TargetHealth.Reason}' \
  --output table

# Expected: All targets show "healthy" state
# If "unhealthy": Check Reason field (e.g., "Target.FailedHealthChecks")
```

**Common health check issues:**

| State     | Reason                            | Solution                                                |
| --------- | --------------------------------- | ------------------------------------------------------- |
| initial   | Target.FailedHealthChecks         | Wait 2-3 minutes for Keycloak startup                   |
| unhealthy | Target.ResponseCodeMismatch       | Check CloudWatch logs for errors                        |
| unhealthy | Target.Timeout                    | Increase health check timeout or check DB connectivity  |
| draining  | Target.DeregistrationInProgress   | Normal during deployment updates                        |

### 4. Monitor CloudWatch Logs

**Tail ECS logs in real-time:**

```bash
# Get log group name from Terraform outputs
LOG_GROUP=$(Terraform output -raw cloudwatch_log_group_name)

# Tail logs (requires AWS CLI v2)
AWS logs tail "$LOG_GROUP" --follow --format short

# Look for successful startup messages:
# - "Keycloak 26.0 (powered by Quarkus)"
# - "Listening on: http://0.0.0.0:8080"
# - "Profile prod activated"
```

**Check for errors:**

```bash
# Search for ERROR level logs in last 30 minutes
AWS logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern "ERROR" \
  --start-time $(($(date +%s) - 1800))000 \
  --query 'events[*].message' \
  --output text

# Expected: No output (no errors)
# If errors found: Review error messages for database, configuration issues
```

### 5. Verify Database Connectivity

**Check RDS instance is available:**

```bash
# Get DB instance ID from Terraform outputs
DB_INSTANCE=$(Terraform output -raw db_instance_id)

# Check RDS status
AWS RDS describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE" \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address,Engine:Engine,Version:EngineVersion}' \
  --output table

# Expected: Status = "available"
```

**Test database connections from ECS:**

```bash
# Check RDS connection count metric
AWS cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value="$DB_INSTANCE" \
  --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --query 'Datapoints[0].Average'

# Expected: Number > 0 (indicates active connections)
# Typical: 10-30 connections for 2 tasks
```

### 6. Test Keycloak Access

**Test HTTP/HTTPS access:**

```bash
# Get Keycloak URL
KEYCLOAK_URL=$(Terraform output -raw keycloak_url)

# Test health endpoint
curl -i "$KEYCLOAK_URL/health/ready"

# Expected: HTTP/1.1 200 OK
# Response body: {"status":"UP","checks":[...]}
```

**Test admin console access:**

```bash
# Test admin console page loads
curl -I "$KEYCLOAK_URL/admin/"

# Expected: HTTP/1.1 200 OK or 302 Found (redirect to login)
```

**Retrieve and test admin credentials:**

```bash
# Get admin credentials
ADMIN_SECRET=$(Terraform output -raw admin_credentials_secret_id)
ADMIN_CREDS=$(AWS secretsmanager get-secret-value \
  --secret-id "$ADMIN_SECRET" \
  --query SecretString \
  --output text)

echo "$ADMIN_CREDS" | jq -r '"Username: \(.username)\nPassword: \(.password)"'

# Test login via browser or API
# Browser: Open $KEYCLOAK_URL/admin and use credentials
```

### 7. Verify Monitoring and Alarms

**Check CloudWatch alarms are created:**

```bash
# List alarms for your deployment
AWS cloudwatch describe-alarms \
  --alarm-name-prefix "$(Terraform output -raw ecs_cluster_name | cut -d'-' -f1)" \
  --query 'MetricAlarms[*].{Name:AlarmName,State:StateValue}' \
  --output table

# Expected: 5 alarms in "OK" state:
# - high-cpu (ECS)
# - high-memory (ECS)
# - unhealthy-targets (ALB)
# - RDS-high-cpu (RDS)
# - RDS-low-storage (RDS)
```

### 8. Deployment Timeline

**Expected deployment duration:**

| Phase                  | Duration        | How to Monitor                         |
| ---------------------- | --------------- | -------------------------------------- |
| Terraform apply        | 15-20 min       | Watch Terraform output                 |
| RDS creation           | 10-12 min       | `AWS RDS describe-db-instances`        |
| ECS service creation   | 2-3 min         | `AWS ECS describe-services`            |
| Container image pull   | 1-2 min         | CloudWatch logs: "Pulling from quay.io"|
| Keycloak startup       | 2-3 min         | CloudWatch logs: "Keycloak started"    |
| Health check pass      | 1-2 min         | `AWS elbv2 describe-target-health`     |
| **Total**              | **15-25 min**   | All targets healthy                    |

**If deployment exceeds 25 minutes:**

- Check CloudWatch logs for errors
- Verify NAT Gateway configuration
- Check ECS service events for failures

### 9. Troubleshooting Failed Deployments

**ECS Tasks Not Starting:**

```bash
# Check task failure reasons
AWS ECS list-tasks --cluster "$CLUSTER_NAME" --desired-status STOPPED --max-items 5

# Get task failure details
AWS ECS describe-tasks \
  --cluster "$CLUSTER_NAME" \
  --tasks <TASK_ARN> \
  --query 'tasks[0].{StopCode:stopCode,StopReason:stoppedReason,Containers:containers[0].reason}'

# Common reasons:
# - "CannotPullContainerError" → Check NAT Gateway
# - "ResourceInitializationError" → Check IAM permissions
# - "OutOfMemoryError" → Increase task_memory
```

**Unhealthy Targets:**

```bash
# Get detailed health check failures
AWS elbv2 describe-target-health \
  --target-group-arn "$TARGET_GROUP_ARN" \
  --query 'TargetHealthDescriptions[?TargetHealth.State==`unhealthy`]'

# Check if it's just startup delay (first 10 minutes)
# If persistent: Check CloudWatch logs for Keycloak errors
```

**Database Connection Errors:**

```bash
# Check for connection errors in logs
AWS logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern "\"connection\" \"database\" \"ERROR\"" \
  --query 'events[*].message'

# Common causes:
# - RDS security group not allowing ECS tasks
# - Database credentials incorrect (check Secrets Manager)
# - RDS not yet available (check status)
```

## Inputs

### Required Variables

| Name | Description | Type |
| ---- | ----------- | ---- |
| name | Name prefix for all resources | string |
| environment | Environment name (e.g., dev, staging, prod) | string |
| vpc_id | VPC ID where resources will be created | string |
| public_subnet_ids | Public subnet IDs for ALB (minimum 2, in different AZs) | list(string) |
| private_subnet_ids | Private subnet IDs for ECS and RDS (minimum 2, in different AZs) | list(string) |

### Networking & Security

| Name | Description | Type | Default |
| ---- | ----------- | ---- | ------- |
| allowed_cidr_blocks | CIDR blocks allowed to access Keycloak (⚠️ 0.0.0.0/0 not allowed for prod) | list(string) | ["0.0.0.0/0"] |
| certificate_arn | ACM certificate ARN for HTTPS | string | "" |
| waf_acl_arn | AWS WAF WebACL ARN (🔴 REQUIRED for prod) | string | "" |
| alb_deletion_protection | Enable ALB deletion protection | bool | true for prod, false otherwise |
| alb_access_logs_enabled | Enable ALB access logs | bool | false |
| alb_access_logs_bucket | S3 bucket for ALB logs | string | "" |
| alb_access_logs_prefix | S3 prefix for ALB logs | string | "" |

### High Availability

| Name | Description | Type | Default |
| ---- | ----------- | ---- | ------- |
| multi_az | Enable multi-AZ deployment | bool | false |
| desired_count | Number of Keycloak tasks | number | 2 |
| autoscaling_max_capacity | Maximum tasks for autoscaling | number | desired_count * 3 |

### ECS Configuration

| Name | Description | Type | Default |
| ---- | ----------- | ---- | ------- |
| Keycloak_version | Keycloak version to deploy | string | "26.0" |
| task_cpu | CPU units (1024 = 1 vCPU) | number | 1024 |
| task_memory | Memory in MB | number | 2048 |
| enable_container_insights | Enable CloudWatch Container Insights | bool | true |
| health_check_grace_period_seconds | ECS health check grace period | number | 600 |

### RDS Configuration

| Name | Description | Type | Default |
| ---- | ----------- | ---- | ------- |
| db_instance_class | RDS instance class | string | "db.t4g.micro" |
| db_allocated_storage | Storage in GB | number | 20 |
| db_max_allocated_storage | Max storage for autoscaling | number | 100 |
| db_engine_version | PostgreSQL version | string | "16.3" |
| db_backup_retention_period | Backup retention days | number | 7 |
| db_backup_window | Backup window | string | "03:00-04:00" |
| db_maintenance_window | Maintenance window | string | "sun:04:00-sun:05:00" |
| db_deletion_protection | Enable deletion protection | bool | true |
| db_skip_final_snapshot | Skip final snapshot on destroy | bool | false |
| db_kms_key_id | KMS key for RDS encryption | string | "" (AWS managed) |
| db_performance_insights_retention_period | Performance Insights retention | number | 7 |
| db_iam_database_authentication_enabled | Enable IAM auth | bool | false |

### Keycloak Configuration

| Name | Description | Type | Default |
| ---- | ----------- | ---- | ------- |
| Keycloak_hostname | Keycloak hostname (recommended for prod) | string | "" |
| Keycloak_admin_username | Admin username | string | "admin" |
| Keycloak_loglevel | Log level (INFO, DEBUG, WARN, ERROR) | string | "INFO" |
| Keycloak_extra_env_vars | Additional environment variables | map(string) | {} |
| Keycloak_cache_enabled | Enable distributed cache | bool | true |
| Keycloak_cache_stack | Cache protocol (tcp, udp, jdbc-ping) | string | "jdbc-ping" |
| db_pool_initial_size | Initial connection pool size | number | 5 |
| db_pool_min_size | Minimum connection pool size | number | 5 |
| db_pool_max_size | Maximum connection pool size | number | 20 |

### Monitoring

| Name | Description | Type | Default |
| ---- | ----------- | ---- | ------- |
| cloudwatch_log_retention_days | Log retention in days | number | 30 for prod, 7 otherwise |

### Encryption

| Name | Description | Type | Default |
| ---- | ----------- | ---- | ------- |
| secrets_kms_key_id | KMS key for Secrets Manager | string | "" (AWS managed) |

### Tags

| Name | Description | Type | Default |
| ---- | ----------- | ---- | ------- |
| tags | Additional resource tags | map(string) | {} |

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

### Production Security Checklist

1. **WAF Protection** (🔴 Required for prod):
   - Protects against OWASP Top 10, DDoS, and credential stuffing
   - See [WAF Setup Guide](#waf-setup-guide) below
   - Cost: ~$5-10/month + $0.60 per million requests

2. **Network Security**:
   - Deploy in private subnets with NAT Gateway
   - Use security groups with minimal access
   - Restrict `allowed_cidr_blocks` to known IP ranges (no 0.0.0.0/0 in prod)

3. **Secrets Management**:
   - All credentials stored in Secrets Manager
   - Never commit secrets to code
   - Optional: Use custom KMS keys for additional control

4. **Encryption**:
   - RDS storage encrypted at rest (default: AWS managed keys)
   - Secrets encrypted in Secrets Manager
   - Optional: Provide custom KMS keys via `db_kms_key_id` and `secrets_kms_key_id`

5. **HTTPS**:
   - Always use ACM certificates for production
   - TLS 1.3 enforced on ALB
   - Automatic HTTP → HTTPS redirect

6. **Deletion Protection**:
   - Enabled by default for RDS in production
   - Enabled by default for ALB in production
   - Prevents accidental deletion

7. **Monitoring**:
   - CloudWatch alarms for critical metrics
   - Container Insights for ECS performance
   - RDS Performance Insights enabled

### WAF Setup Guide

For production deployments, you must configure AWS WAF. Here's a quick setup:

```hcl
# Create WAF WebACL with AWS Managed Rules
resource "aws_wafv2_web_acl" "Keycloak" {
  name  = "${var.name}-Keycloak-${var.environment}"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Core Rule Set - protects against OWASP Top 10
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

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

  # Known Bad Inputs - blocks known malicious patterns
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting - prevent brute force attacks
  rule {
    name     = "RateLimitRule"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000  # requests per 5 minutes per IP
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-Keycloak-${var.environment}"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${var.name}-Keycloak-${var.environment}"
    Environment = var.environment
  }
}

# Use the WAF with Keycloak module
module "Keycloak" {
  source = "./modules/Keycloak"

  # ... other variables ...
  waf_acl_arn = aws_wafv2_web_acl.Keycloak.arn
}
```

### KMS Key Permissions

If you provide custom KMS keys, ensure the following permissions are granted:

**For RDS encryption** (`db_kms_key_id`):

```json
{
  "Sid": "Allow RDS to use the key",
  "Effect": "Allow",
  "Principal": {
    "Service": "RDS.amazonaws.com"
  },
  "Action": [
    "kms:Decrypt",
    "kms:CreateGrant",
    "kms:DescribeKey"
  ],
  "Resource": "*"
}
```

**For Secrets Manager** (`secrets_kms_key_id`):

```json
{
  "Sid": "Allow ECS task execution role",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:AWS:iam::ACCOUNT_ID:role/EXECUTION_ROLE_NAME"
  },
  "Action": [
    "kms:Decrypt",
    "kms:DescribeKey"
  ],
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "kms:ViaService": "secretsmanager.REGION.amazonaws.com"
    }
  }
}
```

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
- Max: `autoscaling_max_capacity` (defaults to `desired_count * 3`)

### Database Connection Pool Sizing

**Critical**: Total database connections = `desired_count` × `db_pool_max_size`

This must be LESS than your RDS `max_connections`:

| Instance Class | Max Connections | Safe Config Examples                     |
|----------------|-----------------|------------------------------------------|
| db.t4g.micro   | ~85             | 2 tasks × 20 pool = 40 connections       |
| db.t4g.small   | ~410            | 5 tasks × 30 pool = 150 connections      |
| db.t4g.medium  | ~820            | 10 tasks × 40 pool = 400 connections     |
| db.r6g.large   | ~1000           | 20 tasks × 40 pool = 800 connections     |

**Best Practices**:

- Leave 20% headroom for admin connections and spikes
- For autoscaling: calculate based on `autoscaling_max_capacity`, not `desired_count`
- Monitor RDS DatabaseConnections metric in CloudWatch
- Adjust pool size before increasing task count

**Example for production**:

```hcl
# 5 tasks with autoscaling to 15
desired_count            = 5
autoscaling_max_capacity = 15
db_pool_max_size        = 30  # 15 tasks × 30 = 450 connections
db_instance_class       = "db.t4g.small"  # supports 410+ connections
```

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
