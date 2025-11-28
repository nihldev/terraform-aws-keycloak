# Aurora Provisioned Example

This example demonstrates a Keycloak deployment using **Aurora PostgreSQL Provisioned** for enhanced high availability and performance.

## Features

- **Aurora Provisioned cluster** with writer and reader instances
- **Multi-AZ deployment** with automatic failover (~30 seconds)
- **Read replicas** (auto-created based on `multi_az` or explicit count)
- **Backtrack** capability (time-travel up to 72 hours)
- **Enhanced Performance Insights** (31-day retention for production)
- **Faster failover** compared to RDS (~30s vs 60-120s)
- **Up to 15 read replicas** (vs 5 for RDS)

## When to Use Aurora Provisioned

Choose Aurora Provisioned when you need:

- High availability with faster failover times
- Multiple read replicas for read-heavy workloads
- Point-in-time recovery with Backtrack feature
- Consistently high database workload
- Production-grade reliability and performance

## Database Configuration

```hcl
database_type = "aurora"

# Instance class for writer and reader instances
db_instance_class = "db.r6g.large"  # Production-ready

# Read replica configuration
aurora_replica_count = null  # Auto: 1 if multi_az=true, 0 otherwise
# Or explicitly set:
# aurora_replica_count = 2  # Create 2 read replicas

# Backtrack window (time-travel for Aurora)
aurora_backtrack_window = null  # Auto: 24h for prod, 0h for non-prod
# Or explicitly set:
# aurora_backtrack_window = 24  # 24 hours (max 72)
```

## Estimated Monthly Cost

**~$600-900 USD** (us-east-1, production configuration)

- Aurora writer instance (db.r6g.large): ~$250
- Aurora reader instance (db.r6g.large): ~$250
- Storage (100GB): ~$10
- I/O operations: ~$50-100
- Backtrack: ~$10-20
- Backup storage: ~$10-20
- ECS Fargate: ~$100-150
- ALB + NAT Gateway: ~$50-80

**Development configuration**: ~$400-500/month with smaller instances (db.r6g.medium)

## Use Cases

- **Production Keycloak deployments** requiring high availability
- **Read-heavy workloads** needing multiple read replicas
- **Compliance requirements** for fast failover and backtrack
- **Large-scale identity management** (1000+ users)
- **Multi-tenant Keycloak** with high transaction volume

## Usage

```bash
cd examples/aurora-provisioned

# Review and customize variables
vim variables.tf

# Initialize
terraform init

# Plan (review the resources that will be created)
terraform plan

# Deploy
terraform apply

# Access Keycloak (takes 15-20 minutes for initial deployment)
terraform output keycloak_url
terraform output keycloak_admin_console_url

# Get database endpoints
terraform output db_cluster_endpoint  # Writer endpoint
terraform output db_reader_endpoint   # Reader endpoint (for read-only queries)

# Get admin credentials
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw admin_credentials_secret_id) \
  --query SecretString --output text | jq .
```

## Customization

### Development Configuration

```hcl
# variables.tf or Terraform.tfvars
environment = "dev"

# Smaller instances for cost savings
db_instance_class = "db.r6g.medium"  # ~$125/month per instance

# Single instance (no replicas)
multi_az = false
aurora_replica_count = 0

# Disable backtrack for dev
aurora_backtrack_window = 0

# Shorter Performance Insights retention
db_performance_insights_retention_period = 7
```

### Production Configuration

```hcl
# variables.tf or Terraform.tfvars
environment = "prod"

# Production-grade instances
db_instance_class = "db.r6g.large"  # or db.r6g.xlarge

# High availability with read replicas
multi_az = true
aurora_replica_count = 2  # 1 writer + 2 readers

# Enable backtrack
aurora_backtrack_window = 24  # 24 hours

# Extended Performance Insights
db_performance_insights_retention_period = 31  # Free tier limit

# Longer backups
db_backup_retention_period = 30
```

## Aurora-Specific Features

### 1. Read Replicas

Aurora automatically load-balances read queries across replicas:

```hcl
# In your application, use reader endpoint for read-only queries
# Writer endpoint: Keycloak-prod-cluster.cluster-xxx.us-east-1.RDS.amazonaws.com
# Reader endpoint: Keycloak-prod-cluster.cluster-ro-xxx.us-east-1.RDS.amazonaws.com
```

### 2. Backtrack (Time-Travel)

Rewind your database to a previous point in time without restoring from backup:

```bash
# Backtrack to 1 hour ago
aws rds backtrack-db-cluster \
  --db-cluster-identifier <cluster-id> \
  --backtrack-to "$(date -u -d '1 hour ago' --iso-8601=seconds)"

# Check backtrack status
aws rds describe-db-clusters \
  --db-cluster-identifier <cluster-id> \
  --query 'DBClusters[0].BacktrackWindow'
```

### 3. Fast Failover

Aurora provides faster failover than RDS:

- Aurora: ~30 seconds
- RDS: 60-120 seconds

Monitor failover events:

```bash
aws rds describe-events \
  --source-type db-cluster \
  --source-identifier <cluster-id> \
  --duration 60
```

## Monitoring

### CloudWatch Metrics

```bash
# Monitor cluster CPU
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBClusterIdentifier,Value=<cluster-id> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Check reader lag
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name AuroraReplicaLag \
  --dimensions Name=DBClusterIdentifier,Value=<cluster-id> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

### Performance Insights

Access Performance Insights in the AWS Console to analyze:

- Top SQL queries
- Database load
- Wait events
- Connection patterns

## Cost Optimization

1. **Use smaller instances for dev/test**:

   ```hcl
   db_instance_class = "db.t4g.medium"  # Burstable for dev
   ```

2. **Disable backtrack for non-production**:

   ```hcl
   aurora_backtrack_window = 0
   ```

3. **Reduce replica count**:

   ```hcl
   aurora_replica_count = 1  # Or 0 for dev
   ```

4. **Schedule dev environment shutdowns** (requires custom automation)

## Comparison to Other Database Options

| Feature | RDS | Aurora Provisioned | Aurora Serverless v2 |
| ------- | --- | ------------------ | -------------------- |
| Failover time | 60-120s | ~30s | ~30s |
| Max read replicas | 5 | 15 | N/A |
| Backtrack | ❌ | ✅ | ❌ |
| Auto-scale compute | ❌ | ❌ | ✅ |
| Monthly cost (prod) | ~$300 | ~$600-900 | ~$200-800 |

## Cleanup

```bash
terraform destroy
```

**Note**: Aurora clusters take 5-10 minutes to delete due to final snapshot creation.

## Troubleshooting

See the [main module troubleshooting section](../../modules/keycloak/README.md#aurora-specific-issues) for Aurora-specific issues.

### Common Issues

1. **Replicas not appearing**: Check `aurora_replica_count` and allow 5-10 minutes for creation
2. **High costs**: Review CloudWatch metrics for unnecessary I/O operations
3. **Backtrack not working**: Only available for Aurora Provisioned (not Serverless)
4. **Connection issues**: Verify you're using the correct endpoint (writer vs reader)

## Next Steps

- Review [Aurora best practices](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.BestPractices.html)
- Set up monitoring and alerting
- Test failover scenarios
- Configure Keycloak caching for better performance
- Consider [aurora-serverless](../aurora-serverless/) for variable workloads
