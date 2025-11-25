# Aurora Serverless v2 Example

This example demonstrates a Keycloak deployment using **Aurora Serverless v2** for automatic capacity scaling based on workload.

## Features

- **Auto-scaling capacity** (ACUs) based on database load
- **Scale to zero-ish** (minimum 0.5 ACU when idle)
- **Fast scaling** (seconds, not minutes)
- **Multi-AZ** with automatic failover (~30 seconds)
- **Cost optimization** for variable workloads
- **Pay only for capacity used** (per-second billing)

## When to Use Aurora Serverless v2

Choose Aurora Serverless v2 when you have:

- **Variable workloads** with peaks and valleys
- **Development/staging environments** used intermittently
- **Unpredictable traffic patterns**
- **Budget constraints** requiring cost optimization
- **Fast startup requirements** (unlike v1, v2 scales instantly)

**Not recommended for**:

- Consistent high-load production workloads (use Aurora Provisioned)
- Scenarios requiring read replicas (not supported in Serverless v2)
- Workloads needing backtrack feature

## Database Configuration

```hcl
database_type = "aurora-serverless"

# Capacity range (Aurora Capacity Units - ACUs)
db_capacity_min = 0.5  # Minimum: 0.5 ACU (1 GB RAM, 0.5 vCPU)
db_capacity_max = 2    # Maximum: 2 ACU (4 GB RAM, 1 vCPU)

# Scales automatically between min and max based on:
# - CPU utilization
# - Connection count
# - Database workload
```

### ACU Capacity Guide

| ACUs | RAM | vCPU | Use Case | Cost/hour |
| ---- | --- | ---- | -------- | --------- |
| 0.5 | 1 GB | 0.5 | Minimal dev/test | ~$0.06 |
| 1 | 2 GB | 1 | Light development | ~$0.12 |
| 2 | 4 GB | 2 | Standard dev/staging | ~$0.24 |
| 4 | 8 GB | 4 | Heavy staging | ~$0.48 |
| 8 | 16 GB | 8 | Light production | ~$0.96 |
| 16 | 32 GB | 16 | Production | ~$1.92 |

## Estimated Monthly Cost

**Development (variable workload)**:

- Minimum: ~$40/month (if at 0.5 ACU most of the time)
- Average: ~$60-100/month (mix of 0.5-2 ACU)
- Maximum: ~$150/month (at 2 ACU constantly)

**Production (with higher max)**:

```hcl
db_capacity_min = 2   # 2 ACU minimum
db_capacity_max = 16  # 16 ACU maximum
```

- Minimum: ~$150/month (at 2 ACU)
- Average: ~$300-400/month (scales between 2-8 ACU)
- Maximum: ~$1,500/month (at 16 ACU constantly)

**Plus**: ECS (~$30-150), ALB (~$20), NAT Gateway (~$30)

## Use Cases

### Ideal For

- **Development environments** (9am-5pm usage, idle otherwise)
- **Staging environments** (used during testing cycles)
- **Periodic batch workloads**
- **Unpredictable SaaS applications**
- **MVP/Proof-of-concept projects**
- **Cost-sensitive startups**

### Not Ideal For

- Steady-state production workloads (use Aurora Provisioned)
- Applications needing read replicas
- Workloads requiring backtrack feature
- Maximum performance scenarios (Provisioned is faster)

## Usage

```bash
cd examples/aurora-serverless

# Review and customize variables
vim variables.tf

# Initialize
Terraform init

# Plan
Terraform plan

# Deploy
Terraform apply

# Monitor capacity scaling
AWS cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ServerlessDatabaseCapacity \
  --dimensions Name=DBClusterIdentifier,Value=$(Terraform output -raw db_cluster_endpoint | cut -d. -f1) \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

## Customization

### Minimal Cost (Development)

```hcl
# variables.tf or Terraform.tfvars
environment = "dev"

# Minimum capacity settings
db_capacity_min = 0.5  # Lowest possible (1 GB RAM)
db_capacity_max = 1    # Cap at 1 ACU for cost control

# Single AZ (not recommended for prod)
multi_az = false

# Minimal ECS
desired_count = 1
task_cpu = 512
task_memory = 1024
```

**Cost**: ~$40-80/month total

### Variable Production Workload

```hcl
# variables.tf or Terraform.tfvars
environment = "prod"

# Higher capacity for production
db_capacity_min = 2    # Start at 2 ACU
db_capacity_max = 16   # Allow scaling to 16 ACU

# Multi-AZ for high availability
multi_az = true

# Larger ECS tasks
desired_count = 2
task_cpu = 1024
task_memory = 2048

# Longer backups
db_backup_retention_period = 30
```

**Cost**: ~$200-800/month (depends on actual usage)

## Scaling Behavior

### How Aurora Serverless v2 Scales

1. **Triggers**: CPU, connections, queries per second
2. **Speed**: Scales in seconds (not minutes like v1)
3. **Granularity**: Scales in increments of 0.5 ACU
4. **Direction**: Scales up quickly, scales down gradually

### Monitoring Scaling

```bash
# Real-time capacity monitoring
watch -n 30 'AWS cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ServerlessDatabaseCapacity \
  --dimensions Name=DBClusterIdentifier,Value=<cluster-id> \
  --start-time $(date -u -d "5 minutes ago" +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average \
  --query "Datapoints[*].[Timestamp,Average]" \
  --output table'
```

### Scaling Patterns

**Typical Dev Environment**:

```text
00:00 - 08:00: 0.5 ACU (idle)
09:00 - 12:00: 1-2 ACU (morning development)
12:00 - 13:00: 0.5-1 ACU (lunch)
13:00 - 17:00: 1-2 ACU (afternoon development)
18:00 - 23:59: 0.5 ACU (idle)

Average: ~0.75 ACU = ~$54/month
```

**Typical Production**:

```text
Peak hours: 4-8 ACU
Off-peak: 2-3 ACU
Night: 1-2 ACU

Average: ~3-4 ACU = ~$220-290/month
```

## Cost Optimization Tips

1. **Set appropriate maximum** to prevent runaway costs:

   ```hcl
   db_capacity_max = 2  # Hard cap at 2 ACU
   ```

2. **Monitor your usage pattern** for a week, then adjust:

   ```bash
   # Check average capacity over past week
   AWS cloudwatch get-metric-statistics \
     --namespace AWS/RDS \
     --metric-name ServerlessDatabaseCapacity \
     --dimensions Name=DBClusterIdentifier,Value=<cluster-id> \
     --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 3600 \
     --statistics Average,Maximum \
     --query 'Datapoints[*].[Average,Maximum]' | \
     jq -s 'add | {avg: (map(.[0]) | add / length), max: (map(.[1]) | max)}'
   ```

3. **Shut down dev environments** when not in use (requires automation):

   ```bash
   # Stop cluster (manual, not automated)
   AWS RDS stop-db-cluster --db-cluster-identifier <cluster-id>
   ```

4. **Use CloudWatch alarms** for cost control:

   ```bash
   AWS cloudwatch put-metric-alarm \
     --alarm-name aurora-capacity-high \
     --alarm-description "Alert when capacity exceeds threshold" \
     --metric-name ServerlessDatabaseCapacity \
     --namespace AWS/RDS \
     --statistic Average \
     --period 300 \
     --threshold 4 \
     --comparison-operator GreaterThanThreshold \
     --evaluation-periods 2
   ```

## Comparison to Aurora Provisioned

| Aspect | Serverless v2 | Provisioned |
| ------ | ------------- | ----------- |
| **Scaling** | Automatic (seconds) | Manual instance resize |
| **Minimum cost** | ~$43/month (0.5 ACU) | ~$125/month (db.t4g.medium) |
| **Read replicas** | Not supported | Up to 15 |
| **Backtrack** | Not supported | Supported |
| **Best for** | Variable workload | Consistent workload |
| **Failover** | ~30 seconds | ~30 seconds |
| **Performance** | Scales with ACUs | Consistent |

## When to Switch to Provisioned

Consider switching from Serverless to Provisioned if:

- Your average capacity is consistently > 8 ACU
- You need read replicas for scaling reads
- You need backtrack functionality
- You want predictable monthly costs
- Performance is more important than cost

## Monitoring and Alerts

### Key Metrics

1. **ServerlessDatabaseCapacity**: Current ACUs in use
2. **CPUUtilization**: Percentage of capacity used
3. **DatabaseConnections**: Active connections
4. **ReadLatency/WriteLatency**: Query performance

### CloudWatch Dashboard

```bash
# Create dashboard
AWS cloudwatch put-dashboard \
  --dashboard-name Keycloak-aurora-serverless \
  --dashboard-body file://dashboard.JSON
```

## Troubleshooting

### Database stuck at max capacity

**Cause**: Workload exceeds max ACU setting

**Solutions**:

1. Increase `db_capacity_max`
2. Optimize Keycloak (enable caching, reduce session size)
3. Consider switching to Aurora Provisioned

### Database not scaling down

**Cause**:

- Active connections preventing scale-down
- Continuous workload
- Connection pooling

**Solution**:

- Review connection pool settings
- Check for long-running queries
- Monitor `DatabaseConnections` metric

### Higher costs than expected

**Check current capacity**:

```bash
AWS cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ServerlessDatabaseCapacity \
  --dimensions Name=DBClusterIdentifier,Value=<cluster-id> \
  --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Average,Maximum
```

## Cleanup

```bash
Terraform destroy
```

## Next Steps

- Monitor your capacity usage for 1-2 weeks
- Adjust `db_capacity_min` and `db_capacity_max` based on patterns
- Set up cost alerts
- Compare costs with [aurora-provisioned](../aurora-provisioned/) if workload is consistent
- Review [complete example](../complete/) for production-ready RDS configuration
