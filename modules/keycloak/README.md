# Keycloak Terraform Module

This module deploys Keycloak on AWS using ECS Fargate with flexible database options (RDS PostgreSQL, Aurora Provisioned, or Aurora Serverless v2) and Application Load Balancer.

## Features

- **ECS Fargate**: Serverless container deployment with auto-scaling
- **Flexible Database Options**: Choose the right database for your needs
  - **RDS PostgreSQL**: Cost-effective, reliable (default)
  - **Aurora Provisioned**: Enhanced HA, up to 15 read replicas, faster failover
  - **Aurora Serverless v2**: Auto-scaling capacity, ideal for variable workloads
- **High Availability**: Optional multi-AZ deployment
- **Security**:
  - Secrets stored in AWS Secrets Manager
  - Security groups with least-privilege access
  - Encrypted database storage
  - HTTPS support with ACM certificates
- **Monitoring**:
  - CloudWatch logs and metrics
  - Pre-configured alarms for CPU, memory, and health
  - Container Insights support
  - Performance Insights enabled by default
- **Auto-scaling**: Automatic scaling based on CPU and memory utilization
- **Production-ready**: Circuit breaker, health checks, and deployment safeguards
- **Aurora Features**: Backtrack (time-travel), read replicas, extended Performance Insights
- **Email Integration (Optional)**: Amazon SES for password resets, email verification, notifications
- **Custom Images (Optional)**: ECR repository support for custom themes, providers, and extensions

## Requirements

- Terraform >= 1.14.0
- AWS Provider ~> 5.0
- Existing VPC with public and private subnets (see Network Prerequisites below)
- (Optional) ACM certificate for HTTPS
- **Python 3.x** (required when `enable_ses = true` for SMTP password derivation)

### Python Requirement for SES

When enabling SES email integration (`enable_ses = true`), Python 3.x must be available on the machine running Terraform. This is because AWS SES SMTP requires a derived password (not raw IAM credentials), and the module uses an external Python script to perform this derivation.

**Using mise (recommended):**

```bash
# Python 3.11 is included in mise.toml
mise install
```

**Manual installation:**

```bash
# macOS
brew install python@3.11

# Ubuntu/Debian
sudo apt-get install python3

# Verify installation
python3 --version
```

If Python is not available and `enable_ses = true`, Terraform will fail during the plan phase with an error about the external data source.

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
Internet → ALB (Public Subnets) → ECS Fargate (Private Subnets) → Database (Private Subnets)
                                                                     (RDS / Aurora / Aurora Serverless)
```

## Database Options

This module supports three database types to match your workload requirements and budget:

### RDS PostgreSQL (Default)

**Best for:** Cost-conscious deployments, predictable workloads, most use cases

```hcl
database_type = "rds"  # Default
```

**Characteristics:**

- ✅ Most cost-effective (~$15-30/month for dev, ~$100-300/month for prod)
- ✅ Proven reliability and performance
- ✅ Up to 5 read replicas
- ✅ Multi-AZ with ~60-120 second failover
- ✅ Storage auto-scaling up to 64 TB

**When to use:**

- Standard production workloads
- Budget-conscious deployments
- Predictable authentication patterns

---

### Aurora Provisioned

**Best for:** High-availability requirements, read-heavy workloads, faster failover

```hcl
database_type = "aurora"
```

**Characteristics:**

- ✅ Enhanced high availability (~30 second failover)
- ✅ Up to 15 read replicas (vs RDS's 5)
- ✅ Backtrack feature (rewind to point in time without restore)
- ✅ Better read scaling for heavy authentication loads
- ✅ Storage auto-scales to 128 TB
- 💰 ~2x cost of RDS (~$30-60/month for dev, ~$300-600/month for prod)

**When to use:**

- Mission-critical production deployments
- Need for faster failover (<30 seconds)
- Read-heavy workloads requiring multiple replicas
- Compliance requirements for point-in-time recovery

**Aurora-specific features:**

- **Backtrack**: Rewind database to any point in last 72 hours without restore
- **Read replicas**: Automatic replica count based on `multi_az` or explicit control
- **Performance Insights**: Extended retention (31 days default for prod)

---

### Aurora Serverless v2

**Best for:** Variable workloads, dev/test environments, unpredictable traffic

```hcl
database_type = "aurora-serverless"
db_capacity_min = 0.5  # Minimum ACUs
db_capacity_max = 4    # Maximum ACUs
```

**Characteristics:**

- ✅ Auto-scales capacity based on load (0.5 to 128 ACUs)
- ✅ Scales to near-zero when idle (huge cost savings for dev/test)
- ✅ Instant scaling during authentication spikes
- ✅ Pay only for capacity used
- 💰 Cost-effective for variable workloads, expensive if always at max capacity

**When to use:**

- Development and test environments (scales to near-zero when idle)
- Unpredictable authentication patterns
- Seasonal workloads with high variability
- Getting started (can scale up as needed)

**Capacity units (ACUs):**

- 1 ACU ≈ 2GB RAM
- 0.5 ACU: Minimal dev/test (~$40/month at 50% utilization)
- 2 ACU: Light production (~$160/month at 50% utilization)
- 8 ACU: Medium production (~$640/month at 50% utilization)

---

### Database Comparison

| Feature | RDS | Aurora Provisioned | Aurora Serverless v2 |
| ------- | --- | ------------------ | -------------------- |
| **Cost (dev)** | ~$15-30/month | ~$30-60/month | ~$20-80/month (varies) |
| **Cost (prod)** | ~$100-300/month | ~$300-600/month | ~$100-800/month (varies) |
| **Failover time** | 60-120 seconds | ~30 seconds | ~30 seconds |
| **Read replicas** | Up to 5 | Up to 15 | N/A (single endpoint) |
| **Max storage** | 64 TB | 128 TB | 128 TB |
| **Backtrack** | ❌ | ✅ 0-72 hours | ❌ |
| **Auto-scaling** | Storage only | Storage only | Compute + Storage |
| **Best for** | Most use cases | HA requirements | Variable workloads |

## Usage

See the [examples](../../examples/) directory for complete, working configurations:

| Example | Description | Database | Cost |
| ------- | ----------- | -------- | ---- |
| [basic](../../examples/basic/) | Minimal dev/test deployment | RDS PostgreSQL | ~$50-70/mo |
| [complete](../../examples/complete/) | Production-ready with HTTPS | RDS PostgreSQL | ~$80-400/mo |
| [aurora-provisioned](../../examples/aurora-provisioned/) | High availability, read replicas | Aurora | ~$400-900/mo |
| [aurora-serverless](../../examples/aurora-serverless/) | Auto-scaling for variable workloads | Aurora Serverless v2 | ~$40-800/mo |
| [ses-email](../../examples/ses-email/) | With SES email integration | RDS PostgreSQL | ~$80-400/mo |

### Quick Start

```hcl
module "keycloak" {
  source = "git::https://github.com/nihldev/terraform-aws-keycloak.git//modules/keycloak?ref=main"

  name        = "myapp"
  environment = "dev"

  vpc_id             = "vpc-xxxxx"
  public_subnet_ids  = ["subnet-xxxxx", "subnet-yyyyy"]
  private_subnet_ids = ["subnet-aaaaa", "subnet-bbbbb"]
}
```

### Custom Domain (Route53)

To use HTTPS with a custom domain, create an ACM certificate and Route53 record:

```hcl
module "keycloak" {
  source = "git::https://github.com/nihldev/terraform-aws-keycloak.git//modules/keycloak?ref=main"

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

# Create Route53 alias record pointing to ALB
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

See the [complete example](../../examples/complete/) for full ACM certificate setup.

## Email Configuration (SES)

This module optionally integrates with Amazon SES to enable Keycloak to send emails for:

- Password reset emails
- Email verification
- Admin notifications
- User account updates

### Enabling SES Integration

```hcl
module "keycloak" {
  source = "path/to/modules/keycloak"

  # ... other configuration ...

  # Enable SES email integration
  enable_ses = true
  ses_domain = "example.com"  # Your verified domain

  # Optional: Automatic DNS record creation (if using Route53)
  ses_route53_zone_id = "Z1234567890ABC"

  # Optional: Custom from email address
  ses_from_email = "keycloak@example.com"

  # Optional: Enable email tracking metrics
  ses_configuration_set_enabled = true
}
```

### SES Sandbox Mode

**Important**: New AWS accounts have SES in sandbox mode, which restricts sending:

- Can only send to verified email addresses
- Limited sending quota (200 emails/day)

To send production emails, you must [request production access](https://docs.aws.amazon.com/ses/latest/dg/request-production-access.html).

### DNS Verification

If you don't provide `ses_route53_zone_id`, you must manually create DNS records:

```bash
# Get required DNS records after deployment
terraform output ses_dns_records_required
```

**Required records:**

1. **TXT record** for domain verification: `_amazonses.example.com`
2. **CNAME records** for DKIM (3 records): `{token}._domainkey.example.com`

### Configuring Keycloak Realm

After deployment, configure each Keycloak realm to use SES SMTP:

1. **Get SMTP credentials**:

   The module automatically derives the SMTP password from the IAM credentials (this is why Python 3.x is required during `terraform apply`). The derived credentials are stored in Secrets Manager:

   ```bash
   # Get the SMTP credentials (password is already derived and ready to use)
   aws secretsmanager get-secret-value \
     --secret-id $(terraform output -raw ses_smtp_credentials_secret_id) \
     --query SecretString --output text | jq .
   ```

   This returns:

   ```json
   {
     "smtp_host": "email-smtp.us-east-1.amazonaws.com",
     "smtp_port": 587,
     "smtp_username": "AKIA...",
     "smtp_password": "BJ2k...",  // Already derived, ready to use
     "from_email": "noreply@example.com",
     "region": "us-east-1"
   }
   ```

2. **Configure SMTP in Keycloak**:

   In the Keycloak Admin Console:
   - Go to **Realm Settings** → **Email**
   - Configure:
     - **From**: `keycloak@example.com` (or your `ses_from_email`)
     - **Host**: `email-smtp.{region}.amazonaws.com`
     - **Port**: `587`
     - **Enable StartTLS**: Yes
     - **Enable Authentication**: Yes
     - **Username**: The `smtp_username` from the secret
     - **Password**: The `smtp_password` from the secret (already derived)

3. **Test email**:
   - Click "Test Connection" in Keycloak
   - Send a test email to verify configuration

For complete SES configuration examples, see the [ses-email example](../../examples/ses-email/).

### Monitoring Email Delivery

If `ses_configuration_set_enabled = true`, CloudWatch metrics are available:

```bash
# Check email delivery metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/SES \
  --metric-name Send \
  --dimensions Name=ConfigurationSetName,Value=$(terraform output -raw ses_configuration_set_name) \
  --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum
```

### SES Costs

SES pricing is very affordable:

- **Sending**: $0.10 per 1,000 emails
- **Receiving**: $0.10 per 1,000 emails (first 1,000 free)
- **Data transfer**: Standard AWS rates

Typical Keycloak usage (password resets, verifications) costs < $1/month for most deployments.

### Troubleshooting SES

#### Emails not being sent

1. **Check SES sandbox status**:

   ```bash
   aws ses get-account-sending-enabled
   ```

2. **Verify domain is verified**:

   ```bash
   aws ses get-identity-verification-attributes \
     --identities $(terraform output -raw ses_domain)
   ```

3. **Check sending quota**:

   ```bash
   aws ses get-send-quota
   ```

#### Emails going to spam

- Ensure DKIM records are properly configured
- Check SPF record for your domain
- Consider adding DMARC record
- Monitor bounce and complaint rates

#### Connection refused from Keycloak

- Verify security groups allow outbound SMTP (port 587)
- Check NAT Gateway is configured for private subnets
- Verify SMTP credentials are correct

## Custom Keycloak Images (ECR)

This module supports deploying custom Keycloak Docker images for scenarios requiring:

- Custom themes (branding, UI customization)
- SPI providers (custom authenticators, social logins)
- Custom extensions and JAR files
- Security compliance (private registry requirement)

### Option 1: Use Your Own Image

If you already have a custom Keycloak image in any registry:

```hcl
module "keycloak" {
  source = "path/to/modules/keycloak"

  # Use custom image from any registry
  keycloak_image = "123456789.dkr.ecr.us-east-1.amazonaws.com/my-Keycloak:v1.0.0"

  # Or from Docker Hub
  # keycloak_image = "myorg/Keycloak-custom:latest"
}
```

### Option 2: Module Creates ECR Repository

Let the module create an ECR repository for you:

```hcl
module "keycloak" {
  source = "path/to/modules/keycloak"

  # Module creates ECR repository
  create_ecr_repository = true

  # Optional: Configure ECR settings
  ecr_image_tag_mutability  = "IMMUTABLE"  # Recommended for production
  ecr_scan_on_push          = true         # Vulnerability scanning
  ecr_image_retention_count = 30           # Keep last 30 images
}
```

After deployment, push your custom image:

```bash
# Get push commands from terraform output
terraform output ecr_push_commands

# Or manually:
# 1. Authenticate
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url)

# 2. Build your image
docker build -t $(terraform output -raw ecr_repository_url):v1.0.0 .

# 3. Push
docker push $(terraform output -raw ecr_repository_url):v1.0.0

# 4. Update Terraform to use the new tag
# keycloak_image = "123456789.dkr.ecr.us-east-1.amazonaws.com/myapp-Keycloak-prod:v1.0.0"
```

### Building Custom Keycloak Images

#### Example Dockerfile

```dockerfile
# Custom Keycloak with themes and providers
FROM quay.io/keycloak/keycloak:26.0 as builder

# Install custom theme
COPY themes/my-theme /opt/Keycloak/themes/my-theme

# Install custom providers (JARs)
COPY providers/*.jar /opt/Keycloak/providers/

# Build optimized Keycloak
RUN /opt/Keycloak/bin/kc.sh build

# Production image
FROM quay.io/keycloak/keycloak:26.0
COPY --from=builder /opt/Keycloak/ /opt/Keycloak/

ENTRYPOINT ["/opt/Keycloak/bin/kc.sh"]
```

#### Example with Custom Theme Only

```dockerfile
FROM quay.io/keycloak/keycloak:26.0

# Copy custom login theme
COPY my-login-theme /opt/Keycloak/themes/my-login-theme

# No build step needed for themes-only customization
ENTRYPOINT ["/opt/Keycloak/bin/kc.sh"]
```

### CI/CD Integration

#### GitHub Actions Example

```yaml
name: Build Keycloak Image

on:
  push:
    branches: [main]
    paths:
      - 'Keycloak/**'

env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: myapp-Keycloak-prod

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, tag, and push image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ GitHub.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG ./Keycloak
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG

          # Also tag as latest
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
```

#### GitLab CI Example

```yaml
build-Keycloak:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  variables:
    DOCKER_TLS_CERTDIR: "/certs"
  before_script:
    - apk add --no-cache AWS-cli
    - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
  script:
    - docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$CI_COMMIT_SHA ./Keycloak
    - docker push $ECR_REGISTRY/$ECR_REPOSITORY:$CI_COMMIT_SHA
  only:
    changes:
      - Keycloak/**
```

### Updating to a New Image Version

After pushing a new image:

1. **Update Terraform variable**:

   ```hcl
   keycloak_image = "123456789.dkr.ecr.us-east-1.amazonaws.com/myapp-Keycloak-prod:v1.1.0"
   ```

2. **Apply changes**:

   ```bash
   terraform plan  # Review changes
   terraform apply # Deploy new image
   ```

3. **ECS performs rolling update**:
   - New tasks start with new image
   - Health checks verify new tasks
   - Old tasks drain and terminate
   - Zero-downtime deployment

### Cross-Account ECR Access

For multi-account setups (e.g., shared ECR in central account):

```hcl
module "keycloak" {
  source = "path/to/modules/keycloak"

  create_ecr_repository   = true
  ecr_allowed_account_ids = ["111111111111", "222222222222"]  # Allow these accounts to pull
}
```

### ECR Security Best Practices

1. **Enable image scanning**:

   ```hcl
   ecr_scan_on_push = true
   ```

2. **Use immutable tags in production**:

   ```hcl
   ecr_image_tag_mutability = "IMMUTABLE"
   ```

3. **Enable KMS encryption**:

   ```hcl
   ecr_kms_key_id = aws_kms_key.ecr.arn
   ```

4. **Set image retention policy** (automatically configured):
   - Keeps last N tagged images
   - Removes untagged images after 7 days

### Troubleshooting Custom Images

#### ECS task fails to start with custom image

1. **Check image exists**:

   ```bash
   aws ecr describe-images --repository-name $(terraform output -raw ecr_repository_name)
   ```

2. **Verify ECS can pull from ECR**:
   - The module automatically grants pull permissions
   - Check CloudWatch logs for pull errors

3. **Test image locally**:

   ```bash
   docker run -it --rm $(terraform output -raw keycloak_image) start --help
   ```

#### Image vulnerabilities found

```bash
# Check scan results
aws ecr describe-image-scan-findings \
  --repository-name $(terraform output -raw ecr_repository_name) \
  --image-id imageTag=latest
```

#### Rolling back to previous image

```hcl
# Change to previous working version
keycloak_image = "123456789.dkr.ecr.us-east-1.amazonaws.com/myapp-Keycloak-prod:v1.0.0"
```

```bash
terraform apply
```

## Pre-Deployment Verification

Before running `terraform apply`, verify your infrastructure meets these requirements:

### 1. Verify NAT Gateway Configuration

**Check NAT Gateway exists:**

```bash
# List NAT Gateways in your VPC
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=<YOUR_VPC_ID>" \
  --query 'NatGateways[*].[NatGatewayId,State,SubnetId]' \
  --output table

# Expected: At least one NAT Gateway in "available" state
```

**Verify private subnet routes to NAT Gateway:**

```bash
# Check route tables for private subnets
aws ec2 describe-route-tables \
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
aws ec2 describe-subnets \
  --subnet-ids subnet-xxxxx subnet-yyyyy \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]' \
  --output table

# Expected: Subnets in different AZs (e.g., us-east-1a, us-east-1b)
```

### 3. Verify DNS Settings

```bash
# Check VPC DNS configuration
aws ec2 describe-vpc-attribute \
  --vpc-id <YOUR_VPC_ID> \
  --attribute enableDnsHostnames

aws ec2 describe-vpc-attribute \
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
   terraform output keycloak_url
   ```

2. Get admin credentials from Secrets Manager:

   ```bash
   aws secretsmanager get-secret-value \
     --secret-id $(terraform output -raw admin_credentials_secret_arn) \
     --query SecretString \
     --output text | jq -r '.username, .password'
   ```

3. Access the admin console at `https://your-domain/admin` or `http://alb-dns/admin`

## Post-Deployment Verification

After running `terraform apply`, verify your deployment is healthy:

### 1. Check Terraform Outputs

```bash
# Verify all outputs are populated
terraform output

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
# Get cluster and service names from terraform outputs
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
SERVICE_NAME=$(terraform output -raw ecs_service_name)

# Check service status
aws ecs describe-services \
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
aws ecs describe-services \
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
# Get target group ARN from terraform outputs
TARGET_GROUP_ARN=$(terraform output -raw target_group_arn)

# Check target health
aws elbv2 describe-target-health \
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
# Get log group name from terraform outputs
LOG_GROUP=$(terraform output -raw cloudwatch_log_group_name)

# Tail logs (requires AWS CLI v2)
aws logs tail "$LOG_GROUP" --follow --format short

# Look for successful startup messages:
# - "Keycloak 26.0 (powered by Quarkus)"
# - "Listening on: http://0.0.0.0:8080"
# - "Profile prod activated"
```

**Check for errors:**

```bash
# Search for ERROR level logs in last 30 minutes
aws logs filter-log-events \
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
# Get DB instance ID from terraform outputs
DB_INSTANCE=$(terraform output -raw db_instance_id)

# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE" \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address,Engine:Engine,Version:EngineVersion}' \
  --output table

# Expected: Status = "available"
```

**Test database connections from ECS:**

```bash
# Check RDS connection count metric
aws cloudwatch get-metric-statistics \
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
KEYCLOAK_URL=$(terraform output -raw keycloak_url)

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
ADMIN_SECRET=$(terraform output -raw admin_credentials_secret_id)
ADMIN_CREDS=$(aws secretsmanager get-secret-value \
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
aws cloudwatch describe-alarms \
  --alarm-name-prefix "$(terraform output -raw ecs_cluster_name | cut -d'-' -f1)" \
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
| `terraform apply`      | 15-20 min       | Watch Terraform output                 |
| RDS creation           | 10-12 min       | `aws rds describe-db-instances`        |
| ECS service creation   | 2-3 min         | `aws ecs describe-services`            |
| Container image pull   | 1-2 min         | CloudWatch logs: "Pulling from quay.io"|
| Keycloak startup       | 2-3 min         | CloudWatch logs: "Keycloak started"    |
| Health check pass      | 1-2 min         | `aws elbv2 describe-target-health`     |
| **Total**              | **15-25 min**   | All targets healthy                    |

**If deployment exceeds 25 minutes:**

- Check CloudWatch logs for errors
- Verify NAT Gateway configuration
- Check ECS service events for failures

### 9. Troubleshooting Failed Deployments

**ECS Tasks Not Starting:**

```bash
# Check task failure reasons
aws ecs list-tasks --cluster "$CLUSTER_NAME" --desired-status STOPPED --max-items 5

# Get task failure details
aws ecs describe-tasks \
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
aws elbv2 describe-target-health \
  --target-group-arn "$TARGET_GROUP_ARN" \
  --query 'TargetHealthDescriptions[?TargetHealth.State==`unhealthy`]'

# Check if it's just startup delay (first 10 minutes)
# If persistent: Check CloudWatch logs for Keycloak errors
```

**Database Connection Errors:**

```bash
# Check for connection errors in logs
aws logs filter-log-events \
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
| alb_stickiness_enabled | Enable session stickiness on ALB target group | bool | false |
| alb_stickiness_duration | Duration in seconds for ALB stickiness cookie (1-604800) | number | 86400 |
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

### Database Configuration

| Name | Description | Type | Default |
| ---- | ----------- | ---- | ------- |
| database_type | Database type: `rds`, `aurora`, or `aurora-serverless` | string | `"rds"` |
| db_instance_class | Instance class for RDS/Aurora (ignored for aurora-serverless) | string | "db.t4g.micro" |
| db_capacity_min | Aurora Serverless v2 minimum ACUs (0.5-128) | number | 0.5 |
| db_capacity_max | Aurora Serverless v2 maximum ACUs (0.5-128) | number | 2 |
| aurora_replica_count | Number of Aurora read replicas (0-15, null=auto based on multi_az) | number | null |
| aurora_backtrack_window | Aurora backtrack hours (0-72, null=24 for prod, 0 for non-prod) | number | null |
| db_allocated_storage | Storage in GB (RDS only) | number | 20 |
| db_max_allocated_storage | Max storage for autoscaling (RDS only) | number | 100 |
| db_engine_version | PostgreSQL version | string | "16.3" |
| db_backup_retention_period | Backup retention days | number | 7 |
| db_backup_window | Backup window | string | "03:00-04:00" |
| db_maintenance_window | Maintenance window | string | "sun:04:00-sun:05:00" |
| db_deletion_protection | Enable deletion protection | bool | true |
| db_skip_final_snapshot | Skip final snapshot on destroy | bool | false |
| db_kms_key_id | KMS key for database encryption | string | "" (AWS managed) |
| db_performance_insights_retention_period | Performance Insights retention (null=31 for Aurora prod, 7 otherwise) | number | null |
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
| alarm_sns_topic_arn | SNS topic ARN for CloudWatch alarm notifications | string | "" |
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
| database_type | Type of database deployed (RDS, aurora, or aurora-serverless) |
| db_instance_id | ID of the database instance or cluster |
| db_instance_address | Address of the database endpoint |
| db_instance_endpoint | Connection endpoint for the database |
| db_reader_endpoint | Reader endpoint for Aurora cluster (empty for RDS) |
| db_credentials_secret_arn | ARN of database credentials secret |
| admin_credentials_secret_arn | ARN of admin credentials secret |
| ECS_cluster_name | Name of the ECS cluster |
| cloudwatch_log_group_name | Name of the CloudWatch log group |
| cost_warning | Cost optimization recommendations |

## Cost Optimization

| Configuration | Database | Monthly Cost | Example |
| ------------- | -------- | ------------ | ------- |
| **Dev (Minimal)** | RDS | ~$50-80 | [basic](../../examples/basic/) |
| **Dev (Scaling)** | Aurora Serverless | ~$40-100 | [aurora-serverless](../../examples/aurora-serverless/) |
| **Prod (Standard)** | RDS | ~$300-500 | [complete](../../examples/complete/) |
| **Prod (HA)** | Aurora | ~$600-900 | [aurora-provisioned](../../examples/aurora-provisioned/) |
| **Prod (Variable)** | Aurora Serverless | ~$200-800 | [aurora-serverless](../../examples/aurora-serverless/) |

**Cost reduction tips:**

- Use `multi_az = false` for non-production
- Reduce `desired_count` to 1 for dev/test
- Use smaller instances (`db.t4g.micro`, `task_cpu = 512`)
- For Aurora Serverless, set low `db_capacity_min` (0.5) to scale down when idle

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

For production deployments, you must configure AWS WAF. Recommended configuration:

1. Create a WAF WebACL with `scope = "REGIONAL"`
2. Add AWS Managed Rules:
   - `AWSManagedRulesCommonRuleSet` - OWASP Top 10 protection
   - `AWSManagedRulesKnownBadInputsRuleSet` - Blocks malicious patterns
3. Add rate limiting rule (e.g., 2000 requests per 5 minutes per IP)
4. Pass the WebACL ARN via `waf_acl_arn` variable

See [AWS WAF documentation](https://docs.aws.amazon.com/waf/latest/developerguide/waf-chapter.html) for detailed setup instructions.

### KMS Key Permissions

If you provide custom KMS keys (`db_kms_key_id` or `secrets_kms_key_id`), ensure the appropriate service principals have decrypt permissions. See [AWS KMS documentation](https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html) for policy examples.

## Monitoring

The module creates CloudWatch alarms for:

- High CPU utilization (ECS & RDS)
- High memory utilization (ECS)
- Unhealthy targets
- Low storage space (RDS)

View logs:

```bash
aws logs tail /ECS/myapp-Keycloak-prod --follow
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
terraform apply -var="keycloak_version=26.1"
```

ECS will perform a rolling update with circuit breaker protection.

## Migrating Between Database Types

This section covers migrating your Keycloak deployment from one database type to another.

### Important Notes

- **Downtime required**: Database migration requires downtime (30-60 minutes)
- **Backup first**: Always create a snapshot before migrating
- **Test in dev**: Test the migration process in a dev environment first
- **One-way process**: Migration creates a new database; rollback requires restoring from backup

### Prerequisites

Before migrating:

1. Create a manual snapshot:

   ```bash
   # For RDS
   aws rds create-db-snapshot \
     --db-instance-identifier <instance-id> \
     --db-snapshot-identifier Keycloak-pre-migration-$(date +%Y%m%d)

   # For Aurora
   aws rds create-db-cluster-snapshot \
     --db-cluster-identifier <cluster-id> \
     --db-cluster-snapshot-identifier Keycloak-pre-migration-$(date +%Y%m%d)
   ```

2. Note current configuration:

   ```bash
   terraform show | grep -A 20 "db_"
   ```

3. Export Keycloak realm configuration (optional but recommended):

   ```bash
   # Via Keycloak admin console: Export realms
   # Or use Keycloak CLI
   ```

### Migration Path 1: RDS → Aurora Provisioned

**Use case**: Upgrading to enhanced HA, faster failover, or need for read replicas

**Steps**:

1. **Update Terraform configuration**:

   ```hcl
   # Change database type
   database_type = "aurora"  # Was "rds"

   # Set Aurora-specific settings
   db_instance_class = "db.r6g.large"  # Aurora instance class
   aurora_replica_count = 1            # Add read replica
   aurora_backtrack_window = 24        # Enable backtrack

   # Remove RDS-specific settings
   # db_allocated_storage = 100  # Not used for Aurora
   ```

2. **Plan the migration**:

   ```bash
   terraform plan -out=migration.tfplan
   ```

   Review the plan carefully. You should see:
   - `aws_db_instance.Keycloak[0]` will be destroyed
   - `aws_rds_cluster.Keycloak[0]` will be created
   - `aws_rds_cluster_instance` resources will be created

3. **Schedule downtime** (recommend 1-hour maintenance window)

4. **Stop Keycloak ECS tasks** to prevent write operations:

   ```bash
   aws ecs update-service \
     --cluster <cluster-name> \
     --service <service-name> \
     --desired-count 0

   # Wait for tasks to stop
   aws ecs wait services-stable --cluster <cluster-name> --services <service-name>
   ```

5. **Create final RDS snapshot**:

   ```bash
   aws rds create-db-snapshot \
     --db-instance-identifier <RDS-instance-id> \
     --db-snapshot-identifier Keycloak-final-snapshot-$(date +%Y%m%d-%H%M)

   # Wait for snapshot to complete
   aws rds wait db-snapshot-completed \
     --db-snapshot-identifier Keycloak-final-snapshot-$(date +%Y%m%d-%H%M)
   ```

6. **Apply Terraform changes**:

   ```bash
   terraform apply migration.tfplan
   ```

   This will:
   - Create Aurora cluster
   - Restore data from RDS snapshot (if using restore method)
   - Update Secrets Manager with new endpoint
   - Delete old RDS instance

   **Note**: Terraform will create a new Aurora cluster. To restore data, you need to either:

   **Option A: Migrate data using pg_dump/pg_restore** (recommended):

   ```bash
   # Export from old RDS
   pg_dump -h <old-RDS-endpoint> -U Keycloak -d Keycloak -F c -f keycloak_backup.dump

   # Import to new Aurora
   pg_restore -h <new-aurora-endpoint> -U Keycloak -d Keycloak keycloak_backup.dump
   ```

   **Option B: Restore Aurora from RDS snapshot** (requires AWS DMS or manual process):
   - This is more complex and requires AWS Database Migration Service (DMS)
   - See AWS documentation for RDS to Aurora migration

7. **Restart Keycloak ECS tasks**:

   ```bash
   aws ecs update-service \
     --cluster <cluster-name> \
     --service <service-name> \
     --desired-count 2  # Or your original desired count
   ```

8. **Verify**:

   ```bash
   # Check Aurora cluster status
   aws rds describe-db-clusters --db-cluster-identifier <cluster-id>

   # Test Keycloak access
   curl -I $(terraform output -raw keycloak_url)

   # Verify admin login
   ```

9. **Monitor** for 24 hours before deleting old RDS snapshot

### Migration Path 2: RDS → Aurora Serverless v2

**Use case**: Variable workload, cost optimization, auto-scaling

**Steps**:

1. **Update Terraform configuration**:

   ```hcl
   # Change database type
   database_type = "aurora-serverless"  # Was "rds"

   # Set serverless capacity
   db_capacity_min = 0.5  # Minimum ACUs
   db_capacity_max = 4    # Maximum ACUs

   # Remove RDS and Provisioned settings
   # db_allocated_storage = 100     # Not used
   # aurora_replica_count = null    # Not supported in Serverless
   # aurora_backtrack_window = null # Not supported in Serverless
   ```

2. **Follow same steps as RDS → Aurora Provisioned** (steps 2-9 above)

3. **Monitor scaling** after migration:

   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/RDS \
     --metric-name ServerlessDatabaseCapacity \
     --dimensions Name=DBClusterIdentifier,Value=<cluster-id> \
     --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 300 \
     --statistics Average,Maximum
   ```

### Migration Path 3: Aurora Provisioned → Aurora Serverless v2

**Use case**: Reduce costs for variable workloads

**Steps**:

1. **Create Aurora Provisioned snapshot**:

   ```bash
   aws rds create-db-cluster-snapshot \
     --db-cluster-identifier <cluster-id> \
     --db-cluster-snapshot-identifier aurora-to-serverless-$(date +%Y%m%d)
   ```

2. **Update configuration**:

   ```hcl
   database_type = "aurora-serverless"  # Was "aurora"

   db_capacity_min = 0.5
   db_capacity_max = 4

   # Remove Provisioned-only settings
   # aurora_replica_count = null    # Not supported
   # aurora_backtrack_window = null # Not supported
   ```

3. **Follow migration steps** (similar to RDS → Aurora)

### Migration Path 4: Aurora Serverless v2 → Aurora Provisioned

**Use case**: Consistent high workload, need read replicas or backtrack

**Steps**:

1. **Analyze your workload** to determine appropriate instance class:

   ```bash
   # Check average ACU usage
   aws cloudwatch get-metric-statistics \
     --namespace AWS/RDS \
     --metric-name ServerlessDatabaseCapacity \
     --dimensions Name=DBClusterIdentifier,Value=<cluster-id> \
     --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 3600 \
     --statistics Average | \
     jq '.Datapoints | map(.Average) | add / length'
   ```

   **ACU to instance class mapping**:
   - 0.5-2 ACU avg → db.t4g.medium / db.r6g.medium
   - 2-4 ACU avg → db.r6g.large
   - 4-8 ACU avg → db.r6g.xlarge
   - 8-16 ACU avg → db.r6g.2xlarge

2. **Update configuration**:

   ```hcl
   database_type = "aurora"  # Was "aurora-serverless"

   db_instance_class = "db.r6g.large"  # Based on your analysis
   aurora_replica_count = 1            # Add read replicas
   aurora_backtrack_window = 24        # Enable backtrack

   # Remove serverless settings
   # db_capacity_min = null
   # db_capacity_max = null
   ```

3. **Follow migration steps** (create snapshot, stop tasks, apply, restart)

### Data Migration Methods

#### Method 1: pg_dump/pg_restore (Recommended)

**Pros**: Simple, reliable, works for all migration paths
**Cons**: Requires downtime

```bash
# 1. Stop application
aws ecs update-service --cluster <cluster> --service <service> --desired-count 0

# 2. Export data
PGPASSWORD=$(aws secretsmanager get-secret-value --secret-id <old-secret-id> \
  --query 'SecretString' --output text | jq -r '.password') \
pg_dump -h <old-endpoint> -U Keycloak -d Keycloak -F c -f keycloak_backup.dump

# 3. Apply Terraform (creates new database)
terraform apply

# 4. Import data
PGPASSWORD=$(aws secretsmanager get-secret-value --secret-id <new-secret-id> \
  --query 'SecretString' --output text | jq -r '.password') \
pg_restore -h <new-endpoint> -U Keycloak -d Keycloak -c keycloak_backup.dump

# 5. Restart application
aws ecs update-service --cluster <cluster> --service <service> --desired-count 2
```

#### Method 2: AWS Database Migration Service (Near-zero downtime)

**Pros**: Minimal downtime, continuous replication
**Cons**: More complex, additional costs

1. Create DMS replication instance
2. Configure source (old database) and target (new database)
3. Create migration task
4. Start replication
5. Monitor replication lag
6. Switch application to new endpoint when lag is minimal

See [AWS DMS documentation](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_GettingStarted.html) for detailed steps.

### Rollback Procedure

If migration fails:

1. **Keep old database snapshot**

2. **Restore from snapshot**:

   ```bash
   # For RDS
   aws rds restore-db-instance-from-db-snapshot \
     --db-instance-identifier Keycloak-rollback \
     --db-snapshot-identifier Keycloak-pre-migration-<date>

   # For Aurora
   aws rds restore-db-cluster-from-snapshot \
     --db-cluster-identifier Keycloak-rollback \
     --snapshot-identifier Keycloak-pre-migration-<date>
   ```

3. **Update Terraform to point back** to old database type

4. **Apply Terraform** to restore security groups and configurations

5. **Restart Keycloak** with old database endpoint

### Migration Checklist

- [ ] Review current database metrics and usage patterns
- [ ] Choose appropriate target database type and sizing
- [ ] Test migration in dev/staging environment
- [ ] Create pre-migration snapshot
- [ ] Schedule maintenance window
- [ ] Notify users of downtime
- [ ] Export Keycloak realm configuration (backup)
- [ ] Stop Keycloak ECS tasks
- [ ] Create final snapshot
- [ ] Apply Terraform changes
- [ ] Migrate data (pg_dump/restore or DMS)
- [ ] Update Secrets Manager (done automatically by Terraform)
- [ ] Restart Keycloak ECS tasks
- [ ] Verify database connectivity
- [ ] Test Keycloak login and basic functionality
- [ ] Monitor for 24-48 hours
- [ ] Delete old database after verification (keep snapshots)

### Cost Considerations

Before migrating, compare costs:

| From | To | Cost Change | Notes |
| ---- | -- | ----------- | ----- |
| RDS (db.t4g.micro) | Aurora Provisioned (db.r6g.large) | +400% | Better performance, HA |
| RDS (db.t4g.micro) | Aurora Serverless (0.5-2 ACU) | +50% to +200% | Variable, depends on usage |
| Aurora Provisioned | Aurora Serverless | -20% to -50% | If workload is variable |
| Aurora Serverless | Aurora Provisioned | +50% to +100% | If using Serverless at high capacity |

Use the cost calculator in each example README for detailed estimates.

## Troubleshooting

### Tasks not starting

1. Check ECS service events:

   ```bash
   aws ecs describe-services --cluster <cluster-name> --services <service-name>
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

### Aurora-Specific Issues

#### Aurora Serverless v2 stuck at minimum capacity

**Symptom**: Database running at minimum ACUs even under load

**Causes**:

- Scaling metrics not triggering scale-up (CPU/connections below threshold)
- Database workload not CPU-intensive enough
- Connection pooling preventing new connections

**Solutions**:

```bash
# Check current capacity
aws rds describe-db-clusters --db-cluster-identifier <cluster-id> \
  --query 'DBClusters[0].ServerlessV2ScalingConfiguration'

# Monitor scaling metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ServerlessDatabaseCapacity \
  --dimensions Name=DBClusterIdentifier,Value=<cluster-id> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

**Recommendations**:

- Increase `db_capacity_max` if you need more headroom
- Review CloudWatch metrics: `ServerlessDatabaseCapacity`, `CPUUtilization`
- Consider Aurora Provisioned if workload is consistently high

#### Aurora backtrack not working

**Symptom**: Cannot backtrack to previous point in time

**Causes**:

- Backtrack only available for Aurora Provisioned (not Serverless or RDS)
- Backtrack window set to 0 hours
- Target time outside backtrack window

**Solutions**:

```hcl
# Enable backtrack in your configuration
aurora_backtrack_window = 24  # Hours (max 72)
```

```bash
# Verify backtrack is enabled
aws rds describe-db-clusters --db-cluster-identifier <cluster-id> \
  --query 'DBClusters[0].BacktrackWindow'

# Perform backtrack
aws rds backtrack-db-cluster \
  --db-cluster-identifier <cluster-id> \
  --backtrack-to "2024-01-15T10:30:00Z"
```

**Note**: Backtrack is only available for Aurora Provisioned with MySQL-compatible engine

#### Aurora read replicas not being created

**Symptom**: No read replicas despite `multi_az = true`

**Verification**:

```bash
# Check cluster instances
aws rds describe-db-cluster-members --db-cluster-identifier <cluster-id>
```

**Causes**:

1. Using Aurora Serverless v2 (read replicas not supported)
2. `aurora_replica_count` explicitly set to 0
3. Instance creation still in progress (can take 5-10 minutes)

**Solutions**:

```hcl
# For Aurora Provisioned with explicit replica count
database_type = "aurora"
aurora_replica_count = 1  # Override auto-detection
```

**Check replica status**:

```bash
# List all cluster members
aws rds describe-db-clusters --db-cluster-identifier <cluster-id> \
  --query 'DBClusters[0].DBClusterMembers[*].[DBInstanceIdentifier,IsClusterWriter]'
```

#### Connection endpoint issues

**Symptom**: Application cannot connect to database

**Causes**:

- Using wrong endpoint (writer vs reader vs cluster)
- Security group not allowing ECS → RDS traffic
- Secrets Manager endpoint not updated

**Solutions**:

1. **Verify endpoints**:

```bash
# Get all endpoints
terraform output db_instance_endpoint  # Writer endpoint
terraform output db_reader_endpoint    # Reader endpoint (Aurora only)

# Or via AWS CLI
aws rds describe-db-clusters --db-cluster-identifier <cluster-id> \
  --query 'DBClusters[0].[Endpoint,ReaderEndpoint,Port]'
```

1. **Check Secrets Manager**:

```bash
# Verify secret contains correct endpoint
aws secretsmanager get-secret-value --secret-id <secret-id> \
  --query 'SecretString' --output text | jq .
```

1. **Test connectivity from ECS task**:

```bash
# Start a one-off task with awscli
aws ecs run-task --cluster <cluster-name> \
  --task-definition <task-def-arn> \
  --network-configuration "awsvpcConfiguration={subnets=[<subnet-id>],securityGroups=[<sg-id>]}" \
  --overrides '{"containerOverrides":[{"name":"Keycloak","command":["sh","-c","apk add PostgreSQL-client && psql -h <endpoint> -U Keycloak -d Keycloak -c \"\\dt\""]}]}'
```

#### Performance Insights showing high load

**Symptom**: Database CPU high, slow queries

**Investigation**:

```bash
# Enable Performance Insights (if not already)
aws rds modify-db-instance --db-instance-identifier <instance-id> \
  --enable-performance-insights \
  --performance-insights-retention-period 7
```

**Common causes for Keycloak**:

- Missing indexes on session tables
- High number of active sessions
- Frequent token validation queries
- Insufficient database capacity

**Solutions**:

1. **For Aurora Serverless v2**: Increase `db_capacity_max`

   ```hcl
   db_capacity_max = 4  # Scale up to 4 ACUs
   ```

2. **For Aurora Provisioned**: Upgrade instance class

   ```hcl
   db_instance_class = "db.r6g.xlarge"  # More CPU/memory
   ```

3. **Add read replicas** (Aurora Provisioned only):

   ```hcl
   aurora_replica_count = 2  # Add 2 read replicas
   ```

4. **Optimize Keycloak**:
   - Enable Keycloak caching
   - Reduce session timeout
   - Use external cache (Redis/Infinispan)

#### Failover taking longer than expected

**Symptom**: 30+ seconds to failover

**Expected failover times**:

- RDS: 60-120 seconds
- Aurora Provisioned: ~30 seconds
- Aurora Serverless v2: ~30 seconds

**Causes**:

- DNS propagation delay
- Application not refreshing connections
- Health check interval too long

**Solutions**:

1. **Reduce DNS TTL** in application connection pool
2. **Use cluster endpoint** (not instance endpoint) for automatic failover
3. **Implement connection retry logic** in application
4. **Monitor failover events**:

```bash
aws rds describe-events --source-type db-cluster \
  --source-identifier <cluster-id> \
  --duration 60
```

#### Cost higher than expected

**Symptom**: Aurora costs exceeding budget

**Common causes**:

1. **Aurora Serverless v2 not scaling down**:

   ```bash
   # Check if capacity is stuck at max
   aws cloudwatch get-metric-statistics \
     --namespace AWS/RDS \
     --metric-name ServerlessDatabaseCapacity \
     --dimensions Name=DBClusterIdentifier,Value=<cluster-id> \
     --statistics Average \
     --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 3600
   ```

2. **I/O costs** (check CloudWatch `VolumeReadIOPs` and `VolumeWriteIOPs`)
3. **Backtrack window** (costs $0.012/GB-hour for changes tracked)
4. **Performance Insights retention** (extended retention costs extra)

**Cost optimization**:

```hcl
# For dev/staging Aurora Serverless
db_capacity_min = 0.5  # Minimum capacity
db_capacity_max = 1    # Cap maximum spend

# Disable backtrack for non-production
aurora_backtrack_window = 0

# Reduce Performance Insights retention
db_performance_insights_retention_period = 7  # Default free tier

# Or switch to RDS for dev
database_type = "rds"
db_instance_class = "db.t4g.micro"
```

**Monitor costs**:

```bash
# Check Aurora I/O costs
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name VolumeReadIOPs \
  --dimensions Name=DBClusterIdentifier,Value=<cluster-id> \
  --statistics Sum \
  --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 86400
```

## License

This module is provided as-is under the MIT License.

<!-- markdownlint-disable -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_external"></a> [external](#requirement\_external) | ~> 2.3 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |
| <a name="provider_external"></a> [external](#provider\_external) | 2.3.5 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_appautoscaling_policy.keycloak_cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.keycloak_memory](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_target.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_cloudwatch_log_group.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.aurora_high_cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.aurora_serverless_high_capacity](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.ecs_high_cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.ecs_high_memory](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.rds_high_cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.rds_low_storage](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.unhealthy_targets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_db_instance.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_parameter_group.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_db_subnet_group.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_ecr_lifecycle_policy.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_lifecycle_policy) | resource |
| [aws_ecr_repository.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_ecr_repository_policy.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository_policy) | resource |
| [aws_ecs_cluster.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_service.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_access_key.ses_smtp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key) | resource |
| [aws_iam_role.ecs_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_task_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.ecs_task_cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.ecs_task_execution_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.ecs_task_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.ecs_task_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_user.ses_smtp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) | resource |
| [aws_iam_user_policy.ses_smtp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy) | resource |
| [aws_lb.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_rds_cluster.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster) | resource |
| [aws_rds_cluster_instance.keycloak_reader](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_instance) | resource |
| [aws_rds_cluster_instance.keycloak_serverless_reader](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_instance) | resource |
| [aws_rds_cluster_instance.keycloak_serverless_writer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_instance) | resource |
| [aws_rds_cluster_instance.keycloak_writer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_instance) | resource |
| [aws_rds_cluster_parameter_group.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_parameter_group) | resource |
| [aws_route53_record.ses_dkim](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.ses_verification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_secretsmanager_secret.keycloak_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.keycloak_db](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.ses_smtp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.keycloak_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.keycloak_db](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.ses_smtp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.ecs_tasks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.alb_egress_to_ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.alb_ingress_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.alb_ingress_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ecs_tasks_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ecs_tasks_ingress_from_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.rds_ingress_from_ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_ses_configuration_set.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_configuration_set) | resource |
| [aws_ses_domain_dkim.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_domain_dkim) | resource |
| [aws_ses_domain_identity.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_domain_identity) | resource |
| [aws_ses_domain_identity_verification.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_domain_identity_verification) | resource |
| [aws_ses_email_identity.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_email_identity) | resource |
| [aws_ses_event_destination.cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_event_destination) | resource |
| [aws_wafv2_web_acl_association.keycloak](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association) | resource |
| [random_password.db_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.keycloak_admin_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [aws_iam_policy_document.ecs_task_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ecs_task_cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ecs_task_execution_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ecs_task_execution_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ecs_task_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ses_send](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [external_external.ses_smtp_password](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alarm_sns_topic_arn"></a> [alarm\_sns\_topic\_arn](#input\_alarm\_sns\_topic\_arn) | SNS topic ARN for CloudWatch alarm notifications. If not provided, alarms will not send notifications. | `string` | `""` | no |
| <a name="input_alb_access_logs_bucket"></a> [alb\_access\_logs\_bucket](#input\_alb\_access\_logs\_bucket) | S3 bucket name for ALB access logs (required if alb\_access\_logs\_enabled is true) | `string` | `""` | no |
| <a name="input_alb_access_logs_enabled"></a> [alb\_access\_logs\_enabled](#input\_alb\_access\_logs\_enabled) | Enable ALB access logs | `bool` | `false` | no |
| <a name="input_alb_access_logs_prefix"></a> [alb\_access\_logs\_prefix](#input\_alb\_access\_logs\_prefix) | S3 bucket prefix for ALB access logs | `string` | `""` | no |
| <a name="input_alb_deletion_protection"></a> [alb\_deletion\_protection](#input\_alb\_deletion\_protection) | Enable deletion protection for ALB (defaults to true for prod environment) | `bool` | `null` | no |
| <a name="input_alb_stickiness_duration"></a> [alb\_stickiness\_duration](#input\_alb\_stickiness\_duration) | Duration in seconds for ALB session stickiness cookie (1-604800). Only used when alb\_stickiness\_enabled is true. | `number` | `86400` | no |
| <a name="input_alb_stickiness_enabled"></a> [alb\_stickiness\_enabled](#input\_alb\_stickiness\_enabled) | Enable session stickiness on the ALB target group.<br/><br/>When enabled, the ALB uses cookies to route requests from the same client<br/>to the same target. This can be useful for:<br/>- Long-running admin operations in Keycloak<br/>- Debugging specific instance behavior<br/>- Scenarios where session affinity is required<br/><br/>Note: Keycloak typically doesn't require stickiness because:<br/>- Sessions are stored in the database<br/>- Distributed cache (jdbc-ping) handles session replication<br/>- All instances can serve any request<br/><br/>Only enable if you have a specific need for session affinity. | `bool` | `false` | no |
| <a name="input_allowed_cidr_blocks"></a> [allowed\_cidr\_blocks](#input\_allowed\_cidr\_blocks) | CIDR blocks allowed to access Keycloak through ALB | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_aurora_backtrack_window"></a> [aurora\_backtrack\_window](#input\_aurora\_backtrack\_window) | Hours to retain backtrack data for Aurora Provisioned (0-72).<br/>Allows rewinding database to any point in time without restore from backup.<br/>Only applies when database\_type = "aurora".<br/><br/>If null (default), automatically sets:<br/>- 24 hours for prod environment<br/>- 0 hours (disabled) for non-prod<br/><br/>Cost: ~$0.012 per million change records/month (typically minimal) | `number` | `null` | no |
| <a name="input_aurora_replica_count"></a> [aurora\_replica\_count](#input\_aurora\_replica\_count) | Number of Aurora read replicas (0-15).<br/>Applies to both database\_type = "aurora" and "aurora-serverless".<br/><br/>If null (default), automatically creates:<br/>- 1 replica when multi\_az = true<br/>- 0 replicas when multi\_az = false<br/><br/>Set explicitly to override automatic behavior.<br/><br/>Note: Aurora storage is always replicated across 3 AZs. Reader instances<br/>provide read scaling and faster failover, not storage redundancy. | `number` | `null` | no |
| <a name="input_autoscaling_max_capacity"></a> [autoscaling\_max\_capacity](#input\_autoscaling\_max\_capacity) | Maximum number of tasks for autoscaling (defaults to desired\_count * 3 if not set) | `number` | `null` | no |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | ACM certificate ARN for HTTPS listener (required for prod, optional for dev/test) | `string` | `""` | no |
| <a name="input_cloudwatch_log_retention_days"></a> [cloudwatch\_log\_retention\_days](#input\_cloudwatch\_log\_retention\_days) | CloudWatch log retention in days (defaults to 30 for prod, 7 for non-prod) | `number` | `null` | no |
| <a name="input_create_ecr_repository"></a> [create\_ecr\_repository](#input\_create\_ecr\_repository) | Create an ECR repository for custom Keycloak images.<br/>When enabled, the module creates:<br/>- ECR repository with image scanning<br/>- Lifecycle policy to manage image retention<br/>- Repository URL output for pushing images<br/><br/>Note: This only creates the repository. To use it:<br/>1. Apply to create the ECR repository<br/>2. Build and push your custom image to the repository<br/>3. Set keycloak\_image to the ECR URL (available as ecr\_repository\_url output) | `bool` | `false` | no |
| <a name="input_database_type"></a> [database\_type](#input\_database\_type) | Database type: rds, aurora, or aurora-serverless.<br/><br/>- rds: Standard RDS PostgreSQL (cost-effective, good for most workloads)<br/>- aurora: Aurora Provisioned (better HA, up to 15 read replicas, faster failover)<br/>- aurora-serverless: Aurora Serverless v2 (auto-scaling, ideal for variable workloads) | `string` | `"rds"` | no |
| <a name="input_db_allocated_storage"></a> [db\_allocated\_storage](#input\_db\_allocated\_storage) | Allocated storage for RDS in GB | `number` | `20` | no |
| <a name="input_db_backup_retention_period"></a> [db\_backup\_retention\_period](#input\_db\_backup\_retention\_period) | Number of days to retain RDS backups | `number` | `7` | no |
| <a name="input_db_backup_window"></a> [db\_backup\_window](#input\_db\_backup\_window) | Preferred backup window | `string` | `"03:00-04:00"` | no |
| <a name="input_db_capacity_max"></a> [db\_capacity\_max](#input\_db\_capacity\_max) | Maximum capacity for Aurora Serverless v2 in ACUs.<br/>Only used when database\_type = "aurora-serverless".<br/>Must be >= db\_capacity\_min. | `number` | `2` | no |
| <a name="input_db_capacity_min"></a> [db\_capacity\_min](#input\_db\_capacity\_min) | Minimum capacity for Aurora Serverless v2 in ACUs (Aurora Capacity Units).<br/>Only used when database\_type = "aurora-serverless".<br/>Range: 0.5 to 128 ACUs (1 ACU ≈ 2GB RAM)<br/><br/>Examples:<br/>- 0.5: Minimal cost for dev/test<br/>- 2: Light production workload<br/>- 8: Medium production workload | `number` | `0.5` | no |
| <a name="input_db_deletion_protection"></a> [db\_deletion\_protection](#input\_db\_deletion\_protection) | Enable deletion protection for database (defaults to true for prod environment) | `bool` | `null` | no |
| <a name="input_db_engine_version"></a> [db\_engine\_version](#input\_db\_engine\_version) | PostgreSQL engine version | `string` | `"16.3"` | no |
| <a name="input_db_iam_database_authentication_enabled"></a> [db\_iam\_database\_authentication\_enabled](#input\_db\_iam\_database\_authentication\_enabled) | Enable IAM database authentication for RDS | `bool` | `false` | no |
| <a name="input_db_instance_class"></a> [db\_instance\_class](#input\_db\_instance\_class) | Database instance class for RDS and Aurora Provisioned.<br/>Examples: db.t4g.micro, db.t4g.small, db.r6g.large<br/><br/>Ignored when database\_type = "aurora-serverless" (use db\_capacity\_min/max instead). | `string` | `"db.t4g.micro"` | no |
| <a name="input_db_kms_key_id"></a> [db\_kms\_key\_id](#input\_db\_kms\_key\_id) | KMS key ID for RDS encryption (uses AWS managed key if not provided) | `string` | `""` | no |
| <a name="input_db_maintenance_window"></a> [db\_maintenance\_window](#input\_db\_maintenance\_window) | Preferred maintenance window | `string` | `"sun:04:00-sun:05:00"` | no |
| <a name="input_db_max_allocated_storage"></a> [db\_max\_allocated\_storage](#input\_db\_max\_allocated\_storage) | Maximum allocated storage for RDS autoscaling in GB | `number` | `100` | no |
| <a name="input_db_parameters"></a> [db\_parameters](#input\_db\_parameters) | Additional PostgreSQL parameters to set in the parameter group.<br/>These are applied in addition to the Keycloak-optimized defaults.<br/><br/>Default parameters (always applied):<br/>- log\_min\_duration\_statement = 1000 (log slow queries > 1s)<br/>- log\_statement = ddl (log schema changes)<br/>- idle\_in\_transaction\_session\_timeout = 600000 (kill idle transactions after 10min)<br/><br/>Example:<br/>db\_parameters = [<br/>  { name = "work\_mem", value = "256MB" },<br/>  { name = "max\_connections", value = "200", apply\_method = "pending-reboot" }<br/>] | <pre>list(object({<br/>    name         = string<br/>    value        = string<br/>    apply_method = optional(string, "immediate")<br/>  }))</pre> | `[]` | no |
| <a name="input_db_performance_insights_retention_period"></a> [db\_performance\_insights\_retention\_period](#input\_db\_performance\_insights\_retention\_period) | Performance Insights retention period in days.<br/><br/>If null (default), automatically sets:<br/>- 31 days for Aurora in prod environment<br/>- 7 days for RDS or non-prod<br/><br/>Valid values: 7, 31, 62, 93, 124, 155, 186, 217, 248, 279, 310, 341, 372,<br/>403, 434, 465, 496, 527, 558, 589, 620, 651, 682, 713, 731 | `number` | `null` | no |
| <a name="input_db_pool_initial_size"></a> [db\_pool\_initial\_size](#input\_db\_pool\_initial\_size) | Initial size of database connection pool | `number` | `5` | no |
| <a name="input_db_pool_max_size"></a> [db\_pool\_max\_size](#input\_db\_pool\_max\_size) | Maximum size of database connection pool per Keycloak instance.<br/><br/>IMPORTANT: Calculate total connections carefully:<br/>Total connections = desired\_count * db\_pool\_max\_size<br/><br/>This must be LESS than your RDS max\_connections setting:<br/>- db.t4g.micro:  ~85 connections available<br/>- db.t4g.small:  ~410 connections available<br/>- db.t4g.medium: ~820 connections available<br/>- db.r6g.large:  ~1000 connections available<br/><br/>Examples:<br/>- desired\_count=2, db\_pool\_max\_size=20 → 40 total (safe for db.t4g.micro)<br/>- desired\_count=3, db\_pool\_max\_size=30 → 90 total (requires at least db.t4g.small)<br/>- desired\_count=10, db\_pool\_max\_size=20 → 200 total (requires at least db.t4g.small)<br/><br/>Leave ~20% headroom for administrative connections and connection spikes. | `number` | `20` | no |
| <a name="input_db_pool_min_size"></a> [db\_pool\_min\_size](#input\_db\_pool\_min\_size) | Minimum size of database connection pool | `number` | `5` | no |
| <a name="input_db_skip_final_snapshot"></a> [db\_skip\_final\_snapshot](#input\_db\_skip\_final\_snapshot) | Skip final snapshot when destroying RDS instance | `bool` | `false` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Number of Keycloak tasks to run | `number` | `2` | no |
| <a name="input_ecr_allowed_account_ids"></a> [ecr\_allowed\_account\_ids](#input\_ecr\_allowed\_account\_ids) | List of AWS account IDs allowed to pull images from this ECR repository.<br/>Useful for cross-account deployments.<br/>Leave empty for same-account only access. | `list(string)` | `[]` | no |
| <a name="input_ecr_image_retention_count"></a> [ecr\_image\_retention\_count](#input\_ecr\_image\_retention\_count) | Number of tagged images to retain in ECR (older images are deleted) | `number` | `30` | no |
| <a name="input_ecr_image_tag_mutability"></a> [ecr\_image\_tag\_mutability](#input\_ecr\_image\_tag\_mutability) | Image tag mutability setting for ECR repository.<br/>- MUTABLE: Tags can be overwritten (convenient for dev)<br/>- IMMUTABLE: Tags cannot be overwritten (recommended for prod) | `string` | `"MUTABLE"` | no |
| <a name="input_ecr_image_tag_prefixes"></a> [ecr\_image\_tag\_prefixes](#input\_ecr\_image\_tag\_prefixes) | Tag prefixes for ECR lifecycle policy retention.<br/>Images with tags matching these prefixes will be retained (up to ecr\_image\_retention\_count).<br/>Common prefixes: "v" (versions), "release", environment names. | `list(string)` | <pre>[<br/>  "v",<br/>  "release",<br/>  "prod",<br/>  "staging",<br/>  "dev"<br/>]</pre> | no |
| <a name="input_ecr_kms_key_id"></a> [ecr\_kms\_key\_id](#input\_ecr\_kms\_key\_id) | KMS key ID for ECR image encryption.<br/>If empty, uses default AES256 encryption.<br/>If provided, uses KMS encryption with the specified key. | `string` | `""` | no |
| <a name="input_ecr_scan_on_push"></a> [ecr\_scan\_on\_push](#input\_ecr\_scan\_on\_push) | Enable vulnerability scanning when images are pushed to ECR | `bool` | `true` | no |
| <a name="input_enable_container_insights"></a> [enable\_container\_insights](#input\_enable\_container\_insights) | Enable CloudWatch Container Insights for ECS cluster | `bool` | `true` | no |
| <a name="input_enable_ses"></a> [enable\_ses](#input\_enable\_ses) | Enable SES integration for Keycloak email functionality.<br/>When enabled, creates:<br/>- SES domain identity with DKIM<br/>- IAM user for SMTP credentials<br/>- Secrets Manager secret with SMTP configuration<br/><br/>Note: SES starts in sandbox mode. You must request production access<br/>to send emails to non-verified addresses. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (e.g., dev, staging, prod) | `string` | n/a | yes |
| <a name="input_health_check_grace_period_seconds"></a> [health\_check\_grace\_period\_seconds](#input\_health\_check\_grace\_period\_seconds) | Health check grace period for ECS service (600 recommended for initial deployments) | `number` | `600` | no |
| <a name="input_health_check_path"></a> [health\_check\_path](#input\_health\_check\_path) | Health check path for ALB target group. Default is Keycloak's standard health endpoint. | `string` | `"/health/ready"` | no |
| <a name="input_keycloak_admin_username"></a> [keycloak\_admin\_username](#input\_keycloak\_admin\_username) | Keycloak admin username | `string` | `"admin"` | no |
| <a name="input_keycloak_cache_enabled"></a> [keycloak\_cache\_enabled](#input\_keycloak\_cache\_enabled) | Enable distributed cache for multi-instance deployments (required when desired\_count > 1) | `bool` | `true` | no |
| <a name="input_keycloak_cache_stack"></a> [keycloak\_cache\_stack](#input\_keycloak\_cache\_stack) | Cache stack protocol for Keycloak clustering. Use 'jdbc-ping' for ECS deployments.<br/><br/>Options:<br/>- jdbc-ping: Database-based discovery (recommended for ECS/Fargate)<br/>- tcp: TCP-based discovery (requires multicast or known hosts)<br/>- udp: UDP multicast discovery (not supported in most cloud VPCs)<br/><br/>Note: 'kubernetes' stack is not supported as this module deploys to ECS, not EKS. | `string` | `"jdbc-ping"` | no |
| <a name="input_keycloak_extra_env_vars"></a> [keycloak\_extra\_env\_vars](#input\_keycloak\_extra\_env\_vars) | Additional environment variables for Keycloak container | `map(string)` | `{}` | no |
| <a name="input_keycloak_hostname"></a> [keycloak\_hostname](#input\_keycloak\_hostname) | Keycloak hostname (required for production deployments) | `string` | `""` | no |
| <a name="input_keycloak_image"></a> [keycloak\_image](#input\_keycloak\_image) | Custom Keycloak Docker image URI.<br/>Use this to deploy a custom Keycloak image with themes, providers, or extensions.<br/><br/>Examples:<br/>- ECR: "123456789.dkr.ecr.us-east-1.amazonaws.com/keycloak:v1.0.0"<br/>- Docker Hub: "myorg/keycloak-custom:latest"<br/><br/>If empty (default), uses the official Keycloak image from quay.io.<br/><br/>To use ECR: Set this to the ECR repository URL from the module output,<br/>e.g., keycloak\_image = module.keycloak.ecr\_repository\_url | `string` | `""` | no |
| <a name="input_keycloak_loglevel"></a> [keycloak\_loglevel](#input\_keycloak\_loglevel) | Keycloak log level (INFO, DEBUG, WARN, ERROR) | `string` | `"INFO"` | no |
| <a name="input_keycloak_version"></a> [keycloak\_version](#input\_keycloak\_version) | Keycloak version to deploy | `string` | `"26.0"` | no |
| <a name="input_multi_az"></a> [multi\_az](#input\_multi\_az) | Enable multi-AZ deployment for high availability.<br/><br/>Behavior by database type:<br/>- RDS: Creates a synchronous standby replica in another AZ (true Multi-AZ)<br/>- Aurora: Sets default for aurora\_replica\_count to 1 (creates a reader instance)<br/>          Note: Aurora storage is ALWAYS replicated across 3 AZs regardless of this setting.<br/><br/>For Aurora, prefer using 'aurora\_replica\_count' directly for explicit control. | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for all resources | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private subnet IDs for ECS tasks and RDS | `list(string)` | n/a | yes |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | Public subnet IDs for Application Load Balancer | `list(string)` | n/a | yes |
| <a name="input_secrets_kms_key_id"></a> [secrets\_kms\_key\_id](#input\_secrets\_kms\_key\_id) | KMS key ID for Secrets Manager encryption (uses AWS managed key if not provided) | `string` | `""` | no |
| <a name="input_ses_configuration_set_enabled"></a> [ses\_configuration\_set\_enabled](#input\_ses\_configuration\_set\_enabled) | Enable SES Configuration Set for email tracking and metrics.<br/>Creates CloudWatch metrics for:<br/>- Send, reject, bounce, complaint events<br/>- Delivery, open, click tracking<br/><br/>Useful for monitoring email deliverability. | `bool` | `false` | no |
| <a name="input_ses_domain"></a> [ses\_domain](#input\_ses\_domain) | Domain to use for sending emails via SES.<br/>This domain will be verified with SES and DKIM will be configured.<br/>Required if enable\_ses = true.<br/>Example: "example.com" or "mail.example.com" | `string` | `""` | no |
| <a name="input_ses_email_identity"></a> [ses\_email\_identity](#input\_ses\_email\_identity) | Optional: Specific email address to verify instead of (or in addition to) domain.<br/>Useful for testing in SES sandbox mode without domain verification.<br/>Example: "noreply@example.com" | `string` | `""` | no |
| <a name="input_ses_from_email"></a> [ses\_from\_email](#input\_ses\_from\_email) | Email address to use as the 'From' address for Keycloak emails.<br/>Must be from the verified domain or verified email identity.<br/>Defaults to "noreply@{ses\_domain}" if not specified.<br/>Example: "keycloak@example.com" or "noreply@example.com" | `string` | `""` | no |
| <a name="input_ses_route53_zone_id"></a> [ses\_route53\_zone\_id](#input\_ses\_route53\_zone\_id) | Route53 hosted zone ID for automatic DNS record creation.<br/>If provided, the module will automatically create:<br/>- TXT record for domain verification<br/>- CNAME records for DKIM<br/><br/>If not provided, you must manually create these DNS records.<br/>The required records will be available in the outputs. | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags for all resources | `map(string)` | `{}` | no |
| <a name="input_task_cpu"></a> [task\_cpu](#input\_task\_cpu) | CPU units for Keycloak task (1024 = 1 vCPU) | `number` | `1024` | no |
| <a name="input_task_memory"></a> [task\_memory](#input\_task\_memory) | Memory for Keycloak task in MB | `number` | `2048` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where resources will be created | `string` | n/a | yes |
| <a name="input_waf_acl_arn"></a> [waf\_acl\_arn](#input\_waf\_acl\_arn) | ARN of AWS WAF WebACL to associate with ALB (STRONGLY RECOMMENDED for production environments to protect against web exploits, DDoS, and credential stuffing attacks) | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_admin_credentials_secret_arn"></a> [admin\_credentials\_secret\_arn](#output\_admin\_credentials\_secret\_arn) | ARN of the Secrets Manager secret containing Keycloak admin credentials |
| <a name="output_admin_credentials_secret_id"></a> [admin\_credentials\_secret\_id](#output\_admin\_credentials\_secret\_id) | Secret ID for retrieving admin credentials (use with AWS CLI: aws secretsmanager get-secret-value --secret-id <this-value>) |
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ARN of the Application Load Balancer |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | DNS name of the Application Load Balancer |
| <a name="output_alb_security_group_id"></a> [alb\_security\_group\_id](#output\_alb\_security\_group\_id) | ID of the ALB security group |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | Zone ID of the Application Load Balancer (for Route53 alias records) |
| <a name="output_cloudwatch_log_group_arn"></a> [cloudwatch\_log\_group\_arn](#output\_cloudwatch\_log\_group\_arn) | ARN of the CloudWatch log group |
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | Name of the CloudWatch log group |
| <a name="output_cost_warning"></a> [cost\_warning](#output\_cost\_warning) | Cost optimization recommendations |
| <a name="output_database_type"></a> [database\_type](#output\_database\_type) | Type of database deployed (rds, aurora, or aurora-serverless) |
| <a name="output_db_credentials_secret_arn"></a> [db\_credentials\_secret\_arn](#output\_db\_credentials\_secret\_arn) | ARN of the Secrets Manager secret containing database credentials |
| <a name="output_db_credentials_secret_id"></a> [db\_credentials\_secret\_id](#output\_db\_credentials\_secret\_id) | Secret ID for retrieving database credentials (use with AWS CLI: aws secretsmanager get-secret-value --secret-id <this-value>) |
| <a name="output_db_instance_address"></a> [db\_instance\_address](#output\_db\_instance\_address) | Address of the database endpoint |
| <a name="output_db_instance_arn"></a> [db\_instance\_arn](#output\_db\_instance\_arn) | ARN of the database instance or cluster |
| <a name="output_db_instance_endpoint"></a> [db\_instance\_endpoint](#output\_db\_instance\_endpoint) | Connection endpoint for the database |
| <a name="output_db_instance_id"></a> [db\_instance\_id](#output\_db\_instance\_id) | ID of the database instance or cluster |
| <a name="output_db_name"></a> [db\_name](#output\_db\_name) | Name of the database |
| <a name="output_db_reader_endpoint"></a> [db\_reader\_endpoint](#output\_db\_reader\_endpoint) | Reader endpoint for Aurora cluster (empty for RDS) |
| <a name="output_ecr_push_commands"></a> [ecr\_push\_commands](#output\_ecr\_push\_commands) | Commands to authenticate and push images to ECR |
| <a name="output_ecr_repository_arn"></a> [ecr\_repository\_arn](#output\_ecr\_repository\_arn) | ARN of the ECR repository (empty if not created) |
| <a name="output_ecr_repository_name"></a> [ecr\_repository\_name](#output\_ecr\_repository\_name) | Name of the ECR repository (empty if not created) |
| <a name="output_ecr_repository_url"></a> [ecr\_repository\_url](#output\_ecr\_repository\_url) | ECR repository URL for pushing custom images (empty if not created) |
| <a name="output_ecs_cluster_id"></a> [ecs\_cluster\_id](#output\_ecs\_cluster\_id) | ID of the ECS cluster |
| <a name="output_ecs_cluster_name"></a> [ecs\_cluster\_name](#output\_ecs\_cluster\_name) | Name of the ECS cluster |
| <a name="output_ecs_service_id"></a> [ecs\_service\_id](#output\_ecs\_service\_id) | ID of the ECS service |
| <a name="output_ecs_service_name"></a> [ecs\_service\_name](#output\_ecs\_service\_name) | Name of the ECS service |
| <a name="output_ecs_task_definition_arn"></a> [ecs\_task\_definition\_arn](#output\_ecs\_task\_definition\_arn) | ARN of the ECS task definition |
| <a name="output_ecs_tasks_security_group_id"></a> [ecs\_tasks\_security\_group\_id](#output\_ecs\_tasks\_security\_group\_id) | ID of the ECS tasks security group |
| <a name="output_keycloak_admin_console_url"></a> [keycloak\_admin\_console\_url](#output\_keycloak\_admin\_console\_url) | URL to access Keycloak admin console |
| <a name="output_keycloak_image"></a> [keycloak\_image](#output\_keycloak\_image) | The Keycloak Docker image being used (official or custom) |
| <a name="output_keycloak_url"></a> [keycloak\_url](#output\_keycloak\_url) | URL to access Keycloak (use this to access the admin console) |
| <a name="output_rds_security_group_id"></a> [rds\_security\_group\_id](#output\_rds\_security\_group\_id) | ID of the RDS security group |
| <a name="output_ses_configuration_set_name"></a> [ses\_configuration\_set\_name](#output\_ses\_configuration\_set\_name) | SES Configuration Set name for email tracking (empty if not enabled) |
| <a name="output_ses_dkim_tokens"></a> [ses\_dkim\_tokens](#output\_ses\_dkim\_tokens) | DKIM tokens for email authentication (add CNAME records to DNS if not using Route53) |
| <a name="output_ses_dns_records_required"></a> [ses\_dns\_records\_required](#output\_ses\_dns\_records\_required) | DNS records required for SES verification (only shown if Route53 zone not provided) |
| <a name="output_ses_domain_identity_arn"></a> [ses\_domain\_identity\_arn](#output\_ses\_domain\_identity\_arn) | ARN of the SES domain identity (empty if SES not enabled) |
| <a name="output_ses_domain_verification_token"></a> [ses\_domain\_verification\_token](#output\_ses\_domain\_verification\_token) | TXT record value for SES domain verification (add to DNS if not using Route53) |
| <a name="output_ses_from_email"></a> [ses\_from\_email](#output\_ses\_from\_email) | Email address configured for sending (use in Keycloak realm settings) |
| <a name="output_ses_smtp_credentials_secret_arn"></a> [ses\_smtp\_credentials\_secret\_arn](#output\_ses\_smtp\_credentials\_secret\_arn) | ARN of the Secrets Manager secret containing SMTP credentials |
| <a name="output_ses_smtp_credentials_secret_id"></a> [ses\_smtp\_credentials\_secret\_id](#output\_ses\_smtp\_credentials\_secret\_id) | Secret ID for retrieving SMTP credentials (use: aws secretsmanager get-secret-value --secret-id <this-value>) |
| <a name="output_ses_smtp_endpoint"></a> [ses\_smtp\_endpoint](#output\_ses\_smtp\_endpoint) | SES SMTP endpoint for Keycloak email configuration |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | ARN of the target group |
<!-- END_TF_DOCS -->
<!-- markdownlint-enable -->