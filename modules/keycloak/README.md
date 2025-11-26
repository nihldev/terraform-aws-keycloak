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
database_type = "RDS"  # Default
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

### Aurora Provisioned Example (High Availability)

```hcl
module "Keycloak" {
  source = "./modules/Keycloak"

  name        = "myapp"
  environment = "prod"

  # Networking
  vpc_id             = "vpc-xxxxx"
  public_subnet_ids  = ["subnet-xxxxx", "subnet-yyyyy", "subnet-zzzzz"]
  private_subnet_ids = ["subnet-aaaaa", "subnet-bbbbb", "subnet-ccccc"]

  # Aurora Provisioned for enhanced HA
  database_type     = "aurora"
  db_instance_class = "db.r6g.large"

  # High availability with read replicas
  multi_az = true  # Automatically creates 1 read replica
  # OR explicitly set: aurora_replica_count = 2  # For 2 read replicas

  # Aurora-specific features
  aurora_backtrack_window = 24  # 24 hours of backtrack (auto-enabled for prod)

  # HTTPS with custom domain
  certificate_arn   = "arn:AWS:acm:us-east-1:xxxxx:certificate/xxxxx"
  keycloak_hostname = "auth.example.com"

  # ECS scaling
  desired_count = 3
  task_cpu      = 2048
  task_memory   = 4096

  # Backup configuration
  db_backup_retention_period = 30
  db_deletion_protection     = true

  tags = {
    Project     = "MyApp"
    Team        = "Platform"
    Environment = "Production"
  }
}

# Access Aurora reader endpoint for read-only queries
output "aurora_reader_endpoint" {
  value = module.Keycloak.db_reader_endpoint
}
```

### Aurora Serverless v2 Example (Variable Workload)

```hcl
module "Keycloak" {
  source = "./modules/Keycloak"

  name        = "myapp"
  environment = "dev"

  # Networking
  vpc_id             = "vpc-xxxxx"
  public_subnet_ids  = ["subnet-xxxxx", "subnet-yyyyy"]
  private_subnet_ids = ["subnet-aaaaa", "subnet-bbbbb"]

  # Aurora Serverless v2 for auto-scaling
  database_type   = "aurora-serverless"
  db_capacity_min = 0.5  # Scales down to 0.5 ACU when idle
  db_capacity_max = 4    # Scales up to 4 ACU during peak load

  # Dev configuration
  multi_az      = false
  desired_count = 1
  task_cpu      = 512
  task_memory   = 1024

  tags = {
    Project     = "MyApp"
    Environment = "Development"
  }
}

# Check for cost warnings
output "cost_warning" {
  value = module.Keycloak.cost_warning
}
```

### Aurora Serverless v2 Example (Production with Auto-Scaling)

```hcl
module "Keycloak" {
  source = "./modules/Keycloak"

  name        = "myapp"
  environment = "prod"

  # Networking
  vpc_id             = "vpc-xxxxx"
  public_subnet_ids  = ["subnet-xxxxx", "subnet-yyyyy", "subnet-zzzzz"]
  private_subnet_ids = ["subnet-aaaaa", "subnet-bbbbb", "subnet-ccccc"]

  # Aurora Serverless v2 for unpredictable workload
  database_type   = "aurora-serverless"
  db_capacity_min = 2   # Minimum 2 ACU (baseline)
  db_capacity_max = 16  # Scale up to 16 ACU during authentication spikes

  # HTTPS
  certificate_arn   = "arn:AWS:acm:us-east-1:xxxxx:certificate/xxxxx"
  keycloak_hostname = "auth.example.com"

  # Production ECS
  multi_az      = true
  desired_count = 3
  task_cpu      = 2048
  task_memory   = 4096

  # Backup configuration
  db_backup_retention_period = 30
  db_deletion_protection     = true

  tags = {
    Project     = "MyApp"
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

## Email Configuration (SES)

This module optionally integrates with Amazon SES to enable Keycloak to send emails for:

- Password reset emails
- Email verification
- Admin notifications
- User account updates

### Enabling SES Integration

```hcl
module "Keycloak" {
  source = "path/to/modules/Keycloak"

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
Terraform output ses_dns_records_required
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

### SES Configuration Examples

#### Development (Sandbox Testing)

```hcl
# For testing without domain verification
enable_ses         = true
ses_domain         = "example.com"
ses_email_identity = "developer@example.com"  # Verify this specific email
```

#### Production with Route53

```hcl
enable_ses                    = true
ses_domain                    = "mail.example.com"
ses_from_email                = "noreply@mail.example.com"
ses_route53_zone_id           = data.aws_route53_zone.main.zone_id
ses_configuration_set_enabled = true  # Enable delivery tracking
```

#### Production with External DNS

```hcl
enable_ses     = true
ses_domain     = "example.com"
ses_from_email = "keycloak@example.com"
# No ses_route53_zone_id - manually create DNS records from output
```

### Monitoring Email Delivery

If `ses_configuration_set_enabled = true`, CloudWatch metrics are available:

```bash
# Check email delivery metrics
AWS cloudwatch get-metric-statistics \
  --namespace AWS/SES \
  --metric-name Send \
  --dimensions Name=ConfigurationSetName,Value=$(Terraform output -raw ses_configuration_set_name) \
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
   AWS ses get-account-sending-enabled
   ```

2. **Verify domain is verified**:

   ```bash
   AWS ses get-identity-verification-attributes \
     --identities $(Terraform output -raw ses_domain)
   ```

3. **Check sending quota**:

   ```bash
   AWS ses get-send-quota
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
module "Keycloak" {
  source = "path/to/modules/Keycloak"

  # Use custom image from any registry
  keycloak_image = "123456789.dkr.ecr.us-east-1.amazonaws.com/my-Keycloak:v1.0.0"

  # Or from Docker Hub
  # keycloak_image = "myorg/Keycloak-custom:latest"
}
```

### Option 2: Module Creates ECR Repository

Let the module create an ECR repository for you:

```hcl
module "Keycloak" {
  source = "path/to/modules/Keycloak"

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
# Get push commands from Terraform output
Terraform output ecr_push_commands

# Or manually:
# 1. Authenticate
AWS ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $(Terraform output -raw ecr_repository_url)

# 2. Build your image
docker build -t $(Terraform output -raw ecr_repository_url):v1.0.0 .

# 3. Push
docker push $(Terraform output -raw ecr_repository_url):v1.0.0

# 4. Update Terraform to use the new tag
# keycloak_image = "123456789.dkr.ecr.us-east-1.amazonaws.com/myapp-Keycloak-prod:v1.0.0"
```

### Building Custom Keycloak Images

#### Example Dockerfile

```dockerfile
# Custom Keycloak with themes and providers
FROM quay.io/Keycloak/Keycloak:26.0 as builder

# Install custom theme
COPY themes/my-theme /opt/Keycloak/themes/my-theme

# Install custom providers (JARs)
COPY providers/*.jar /opt/Keycloak/providers/

# Build optimized Keycloak
RUN /opt/Keycloak/bin/kc.sh build

# Production image
FROM quay.io/Keycloak/Keycloak:26.0
COPY --from=builder /opt/Keycloak/ /opt/Keycloak/

ENTRYPOINT ["/opt/Keycloak/bin/kc.sh"]
```

#### Example with Custom Theme Only

```dockerfile
FROM quay.io/Keycloak/Keycloak:26.0

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
        uses: AWS-actions/configure-AWS-credentials@v4
        with:
          AWS-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: AWS-actions/amazon-ecr-login@v2

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
    - AWS ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
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
   Terraform plan  # Review changes
   Terraform apply # Deploy new image
   ```

3. **ECS performs rolling update**:
   - New tasks start with new image
   - Health checks verify new tasks
   - Old tasks drain and terminate
   - Zero-downtime deployment

### Cross-Account ECR Access

For multi-account setups (e.g., shared ECR in central account):

```hcl
module "Keycloak" {
  source = "path/to/modules/Keycloak"

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
   AWS ecr describe-images --repository-name $(Terraform output -raw ecr_repository_name)
   ```

2. **Verify ECS can pull from ECR**:
   - The module automatically grants pull permissions
   - Check CloudWatch logs for pull errors

3. **Test image locally**:

   ```bash
   docker run -it --rm $(Terraform output -raw keycloak_image) start --help
   ```

#### Image vulnerabilities found

```bash
# Check scan results
AWS ecr describe-image-scan-findings \
  --repository-name $(Terraform output -raw ecr_repository_name) \
  --image-id imageTag=latest
```

#### Rolling back to previous image

```hcl
# Change to previous working version
keycloak_image = "123456789.dkr.ecr.us-east-1.amazonaws.com/myapp-Keycloak-prod:v1.0.0"
```

```bash
Terraform apply
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

### Database Configuration

| Name | Description | Type | Default |
| ---- | ----------- | ---- | ------- |
| database_type | Database type: `RDS`, `aurora`, or `aurora-serverless` | string | "RDS" |
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

### Development/Testing (RDS - Most Cost-Effective)

```hcl
database_type              = "RDS"  # Default, most cost-effective
multi_az                   = false
desired_count              = 1
task_cpu                   = 512
task_memory                = 1024
db_instance_class          = "db.t4g.micro"
db_backup_retention_period = 1
```

Estimated cost: ~$50-80/month

---

### Development/Testing (Aurora Serverless - Auto-Scaling)

```hcl
database_type              = "aurora-serverless"
db_capacity_min            = 0.5  # Scales to near-zero when idle
db_capacity_max            = 2
multi_az                   = false
desired_count              = 1
task_cpu                   = 512
task_memory                = 1024
db_backup_retention_period = 1
```

Estimated cost: ~$40-100/month (depends on usage pattern, scales to near-zero when idle)

---

### Production (RDS - Balanced)

```hcl
database_type              = "RDS"
multi_az                   = true
desired_count              = 3
task_cpu                   = 1024
task_memory                = 2048
db_instance_class          = "db.r6g.large"
db_backup_retention_period = 30
```

Estimated cost: ~$300-500/month

---

### Production (Aurora Provisioned - High Availability)

```hcl
database_type              = "aurora"
multi_az                   = true  # Creates 1 read replica automatically
desired_count              = 3
task_cpu                   = 1024
task_memory                = 2048
db_instance_class          = "db.r6g.large"
aurora_backtrack_window    = 24  # Time-travel feature
db_backup_retention_period = 30
```

Estimated cost: ~$600-900/month (includes writer + 1 reader)

---

### Production (Aurora Serverless - Variable Workload)

```hcl
database_type              = "aurora-serverless"
db_capacity_min            = 2   # Baseline capacity
db_capacity_max            = 16  # Scale during spikes
multi_az                   = true
desired_count              = 3
task_cpu                   = 1024
task_memory                = 2048
db_backup_retention_period = 30
```

Estimated cost: ~$200-800/month (depends on load patterns)

---

### Cost Comparison Summary

| Configuration | Database Type | Monthly Cost | Best For |
| ------------- | ------------- | ------------ | -------- |
| **Dev (Minimal)** | RDS | ~$50-80 | Consistent low usage |
| **Dev (Scaling)** | Aurora Serverless | ~$40-100 | Variable/idle periods |
| **Prod (Standard)** | RDS | ~$300-500 | Most production use cases |
| **Prod (HA)** | Aurora Provisioned | ~$600-900 | Mission-critical, read-heavy |
| **Prod (Variable)** | Aurora Serverless | ~$200-800 | Unpredictable patterns |

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
   AWS RDS create-db-snapshot \
     --db-instance-identifier <instance-id> \
     --db-snapshot-identifier Keycloak-pre-migration-$(date +%Y%m%d)

   # For Aurora
   AWS RDS create-db-cluster-snapshot \
     --db-cluster-identifier <cluster-id> \
     --db-cluster-snapshot-identifier Keycloak-pre-migration-$(date +%Y%m%d)
   ```

2. Note current configuration:

   ```bash
   Terraform show | grep -A 20 "db_"
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
   database_type = "aurora"  # Was "RDS"

   # Set Aurora-specific settings
   db_instance_class = "db.r6g.large"  # Aurora instance class
   aurora_replica_count = 1            # Add read replica
   aurora_backtrack_window = 24        # Enable backtrack

   # Remove RDS-specific settings
   # db_allocated_storage = 100  # Not used for Aurora
   ```

2. **Plan the migration**:

   ```bash
   Terraform plan -out=migration.tfplan
   ```

   Review the plan carefully. You should see:
   - `aws_db_instance.Keycloak[0]` will be destroyed
   - `aws_rds_cluster.Keycloak[0]` will be created
   - `aws_rds_cluster_instance` resources will be created

3. **Schedule downtime** (recommend 1-hour maintenance window)

4. **Stop Keycloak ECS tasks** to prevent write operations:

   ```bash
   AWS ECS update-service \
     --cluster <cluster-name> \
     --service <service-name> \
     --desired-count 0

   # Wait for tasks to stop
   AWS ECS wait services-stable --cluster <cluster-name> --services <service-name>
   ```

5. **Create final RDS snapshot**:

   ```bash
   AWS RDS create-db-snapshot \
     --db-instance-identifier <RDS-instance-id> \
     --db-snapshot-identifier Keycloak-final-snapshot-$(date +%Y%m%d-%H%M)

   # Wait for snapshot to complete
   AWS RDS wait db-snapshot-completed \
     --db-snapshot-identifier Keycloak-final-snapshot-$(date +%Y%m%d-%H%M)
   ```

6. **Apply Terraform changes**:

   ```bash
   Terraform apply migration.tfplan
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
   AWS ECS update-service \
     --cluster <cluster-name> \
     --service <service-name> \
     --desired-count 2  # Or your original desired count
   ```

8. **Verify**:

   ```bash
   # Check Aurora cluster status
   AWS RDS describe-db-clusters --db-cluster-identifier <cluster-id>

   # Test Keycloak access
   curl -I $(Terraform output -raw keycloak_url)

   # Verify admin login
   ```

9. **Monitor** for 24 hours before deleting old RDS snapshot

### Migration Path 2: RDS → Aurora Serverless v2

**Use case**: Variable workload, cost optimization, auto-scaling

**Steps**:

1. **Update Terraform configuration**:

   ```hcl
   # Change database type
   database_type = "aurora-serverless"  # Was "RDS"

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
   AWS cloudwatch get-metric-statistics \
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
   AWS RDS create-db-cluster-snapshot \
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
   AWS cloudwatch get-metric-statistics \
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
AWS ECS update-service --cluster <cluster> --service <service> --desired-count 0

# 2. Export data
PGPASSWORD=$(AWS secretsmanager get-secret-value --secret-id <old-secret-id> \
  --query 'SecretString' --output text | jq -r '.password') \
pg_dump -h <old-endpoint> -U Keycloak -d Keycloak -F c -f keycloak_backup.dump

# 3. Apply Terraform (creates new database)
Terraform apply

# 4. Import data
PGPASSWORD=$(AWS secretsmanager get-secret-value --secret-id <new-secret-id> \
  --query 'SecretString' --output text | jq -r '.password') \
pg_restore -h <new-endpoint> -U Keycloak -d Keycloak -c keycloak_backup.dump

# 5. Restart application
AWS ECS update-service --cluster <cluster> --service <service> --desired-count 2
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
   AWS RDS restore-db-instance-from-db-snapshot \
     --db-instance-identifier Keycloak-rollback \
     --db-snapshot-identifier Keycloak-pre-migration-<date>

   # For Aurora
   AWS RDS restore-db-cluster-from-snapshot \
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
AWS RDS describe-db-clusters --db-cluster-identifier <cluster-id> \
  --query 'DBClusters[0].ServerlessV2ScalingConfiguration'

# Monitor scaling metrics
AWS cloudwatch get-metric-statistics \
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
AWS RDS describe-db-clusters --db-cluster-identifier <cluster-id> \
  --query 'DBClusters[0].BacktrackWindow'

# Perform backtrack
AWS RDS backtrack-db-cluster \
  --db-cluster-identifier <cluster-id> \
  --backtrack-to "2024-01-15T10:30:00Z"
```

**Note**: Backtrack is only available for Aurora Provisioned with MySQL-compatible engine

#### Aurora read replicas not being created

**Symptom**: No read replicas despite `multi_az = true`

**Verification**:

```bash
# Check cluster instances
AWS RDS describe-db-cluster-members --db-cluster-identifier <cluster-id>
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
AWS RDS describe-db-clusters --db-cluster-identifier <cluster-id> \
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
Terraform output db_instance_endpoint  # Writer endpoint
Terraform output db_reader_endpoint    # Reader endpoint (Aurora only)

# Or via AWS CLI
AWS RDS describe-db-clusters --db-cluster-identifier <cluster-id> \
  --query 'DBClusters[0].[Endpoint,ReaderEndpoint,Port]'
```

1. **Check Secrets Manager**:

```bash
# Verify secret contains correct endpoint
AWS secretsmanager get-secret-value --secret-id <secret-id> \
  --query 'SecretString' --output text | jq .
```

1. **Test connectivity from ECS task**:

```bash
# Start a one-off task with awscli
AWS ECS run-task --cluster <cluster-name> \
  --task-definition <task-def-arn> \
  --network-configuration "awsvpcConfiguration={subnets=[<subnet-id>],securityGroups=[<sg-id>]}" \
  --overrides '{"containerOverrides":[{"name":"Keycloak","command":["sh","-c","apk add PostgreSQL-client && psql -h <endpoint> -U Keycloak -d Keycloak -c \"\\dt\""]}]}'
```

#### Performance Insights showing high load

**Symptom**: Database CPU high, slow queries

**Investigation**:

```bash
# Enable Performance Insights (if not already)
AWS RDS modify-db-instance --db-instance-identifier <instance-id> \
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
AWS RDS describe-events --source-type db-cluster \
  --source-identifier <cluster-id> \
  --duration 60
```

#### Cost higher than expected

**Symptom**: Aurora costs exceeding budget

**Common causes**:

1. **Aurora Serverless v2 not scaling down**:

   ```bash
   # Check if capacity is stuck at max
   AWS cloudwatch get-metric-statistics \
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
database_type = "RDS"
db_instance_class = "db.t4g.micro"
```

**Monitor costs**:

```bash
# Check Aurora I/O costs
AWS cloudwatch get-metric-statistics \
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
