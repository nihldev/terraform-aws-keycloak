# Keycloak Module Tests

This directory contains automated tests for the Keycloak Terraform module using Terraform's native testing framework.

## Test Framework

We use **Terraform's native testing framework** (`.tftest.hcl` files). This provides:

- Native HCL syntax for test definitions
- Built-in support for assertions and validations
- No external dependencies (no Go, no Terratest)
- Fast execution and easy maintenance

## Prerequisites

- Terraform >= 1.14.0
- AWS credentials configured
- AWS permissions to create:
  - VPC, Subnets, NAT Gateway, Internet Gateway
  - ECS Cluster, Services, Tasks
  - RDS PostgreSQL instances
  - Application Load Balancer
  - Secrets Manager secrets
  - CloudWatch Logs and Alarms
  - IAM roles and policies

## Test Files

### Example Tests

| Test File                        | Description                                       | Duration    | AWS Cost |
| -------------------------------- | ------------------------------------------------- | ----------- | -------- |
| `examples_basic.tftest.hcl`      | Minimal deployment (1 task, smallest instances)   | ~15-20 min  | ~$0.50   |
| `examples_complete.tftest.hcl`   | Complete deployment (2 tasks, standard config)    | ~20-25 min  | ~$1.00   |

### Feature Tests

| Test File                          | Description                                                  | Type               |
| ---------------------------------- | ------------------------------------------------------------ | ------------------ |
| `aurora_database.tftest.hcl`       | Aurora Provisioned and Serverless database configurations    | Plan Only          |
| `ses_email.tftest.hcl`             | SES email integration                                        | Plan Only          |

### Validation Tests

| Test File                          | Description                                                  | Type               |
| ---------------------------------- | ------------------------------------------------------------ | ------------------ |
| `outputs_validation.tftest.hcl`    | Validates all outputs are present and formatted correctly    | Apply + Assertions |
| `module_validation.tftest.hcl`     | Validates terraform plan creates expected resources          | Plan Only          |
| `variable_combinations.tftest.hcl` | Tests various variable combinations and edge cases           | Plan Only          |

## Running Tests

### Run All Tests

```bash
# From repository root
terraform test

# Expected output:
# examples_basic.tftest.hcl... pass
# examples_complete.tftest.hcl... pass
# outputs_validation.tftest.hcl... pass
# module_validation.tftest.hcl... pass
```

### Run Specific Test

```bash
# Run only basic example test
terraform test ./tests/examples_basic.tftest.hcl

# Run with verbose output
terraform test -verbose ./tests/examples_basic.tftest.hcl

# Run without cleanup (keep resources for inspection)
terraform test -no-cleanup ./tests/examples_basic.tftest.hcl
```

### Run Quick Validation (Plan Only)

```bash
# Only validates configuration, doesn't create resources
terraform test ./tests/module_validation.tftest.hcl

# Fast execution (~1-2 minutes)
```

## Test Execution Flow

Each test follows this pattern:

1. **Initialize**: terraform initializes the test module
2. **Plan**: Creates execution plan
3. **Apply**: Deploys resources to AWS (for `command = apply` tests)
4. **Assert**: Validates outputs and conditions
5. **Destroy**: Automatically cleans up resources (unless `-no-cleanup` flag used)

## Understanding Test Files

### Basic Test Structure

```hcl
# Minimal test - just validates deployment succeeds
run "validate_basic" {
  command = apply

  module {
    source = "./examples/basic"
  }
}
```

### Test with Assertions

```hcl
# Test with output validation
run "validate_outputs" {
  command = apply

  module {
    source = "./examples/basic"
  }

  # Validate output exists
  assert {
    condition     = output.keycloak_url != ""
    error_message = "Keycloak URL should not be empty"
  }

  # Validate output format
  assert {
    condition     = can(regex("^http://", output.keycloak_url))
    error_message = "URL should start with http://"
  }
}
```

### Test with Custom Variables

```hcl
# Test with overridden variables
run "validate_custom_config" {
  command = apply

  variables {
    name        = "custom-test"
    environment = "testing"
  }

  module {
    source = "./examples/basic"
  }
}
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Terraform Tests

on:
  pull_request:
    paths:
      - 'modules/Keycloak/**'
      - 'examples/**'
      - 'tests/**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.14.0"

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-region: us-east-1
          role-to-assume: ${{ secrets.AWS_TEST_ROLE }}

      - name: Run Terraform Tests
        run: terraform test
```

## Test Coverage

Our tests validate:

### ✅ Resource Creation

- VPC and networking components
- ECS cluster, service, and tasks
- RDS PostgreSQL instance
- Application Load Balancer
- Security groups and IAM roles
- Secrets Manager secrets
- CloudWatch logs and alarms

### ✅ Configuration Validation

- All required variables have defaults
- Module applies without errors
- No resource conflicts or circular dependencies
- Proper resource naming and tagging

### ✅ Output Validation

- All outputs are generated correctly
- Output formats match expected patterns
- URLs and endpoints are properly formed
- Secret IDs and ARNs are valid

### ✅ Integration Testing

- VPC module integration
- Multi-AZ configuration
- NAT Gateway connectivity
- Database connectivity
- Load balancer health checks

## Troubleshooting

### Test Fails with "CannotPullContainerError"

**Cause**: NAT Gateway not configured or routing issues

**Solution**:

```bash
# Verify NAT Gateway exists
aws ec2 describe-nat-gateways --filter "Name=state,Values=available"

# Check route tables
aws ec2 describe-route-tables
```

### Test Times Out

**Cause**: RDS creation takes 10-15 minutes

**Solution**: Be patient. Initial deployment takes 15-25 minutes.

### Test Fails with "Too Many Connections"

**Cause**: Connection pool size exceeds RDS limits

**Solution**: This shouldn't happen with default configs, but if it does:

```hcl
# In test example, reduce pool size
db_pool_max_size = 10
```

### Resources Not Cleaned Up

**Cause**: Test interrupted or used `-no-cleanup` flag

**Solution**:

```bash
# Manually destroy test resources
cd examples/basic  # or examples/complete
terraform destroy
```

## Cost Management

### Estimated Test Costs

| Test Type         | Duration    | Approximate Cost |
| ----------------- | ----------- | ---------------- |
| Basic Example     | 20 min      | $0.30 - $0.50    |
| Complete Example  | 25 min      | $0.60 - $1.00    |
| All Tests         | 45-60 min   | $1.00 - $2.00    |

**Cost Breakdown:**

- ECS Fargate: $0.04 per hour
- RDS db.t4g.micro: $0.017 per hour
- NAT Gateway: $0.045 per hour
- ALB: $0.025 per hour

### Cost Optimization Tips

1. **Run tests during business hours** (avoid weekend/holiday charges)
2. **Use basic example for quick validation** (50% cheaper than complete)
3. **Monitor for stuck resources**:

   ```bash
   # Check for running ECS tasks
   aws ecs list-tasks --cluster Keycloak-test-Keycloak-test

   # Check for RDS instances
   aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus]'
   ```

4. **Set AWS budgets** to alert on unexpected costs

## Adding New Tests

### 1. Create Example Module

```bash
# Create new example directory
mkdir -p examples/my-new-feature

# Add main.tf, variables.tf, outputs.tf
# Ensure all variables have defaults
```

### 2. Create Test File

```bash
# Create test file
cat > tests/examples_my_new_feature.tftest.hcl << 'EOF'
run "validate_my_new_feature" {
  command = apply

  module {
    source = "./examples/my-new-feature"
  }

  assert {
    condition     = output.some_output != ""
    error_message = "Output should not be empty"
  }
}
EOF
```

### 3. Test Locally

```bash
# Run your new test
terraform test ./tests/examples_my_new_feature.tftest.hcl -verbose

# Verify cleanup
AWS resourcegroupstaggingapi get-resources \
  --tag-filters Key=ManagedBy,Values=Terraform \
  --resource-type-filters ECS:cluster RDS:db
```

### 4. Document the Test

Update this README with:

- Test description
- Expected duration
- Any special requirements

## Coverage Analysis

### Measuring Coverage

We provide a test coverage analysis script to measure how well your tests cover the module:

```bash
# Run coverage analysis
./scripts/check-test-coverage.sh
```

The script analyzes:

1. **Resource Coverage** (41 resources)
   - All AWS resources defined in the module
   - Validated by successful test execution

2. **Variable Coverage** (44 variables)
   - Percentage of variables tested with custom values
   - Identifies untested variables

3. **Output Coverage** (25 outputs)
   - Percentage of outputs validated with assertions
   - Shows which outputs lack validation

4. **Example Coverage** (2 examples)
   - Percentage of examples with corresponding tests
   - Identifies examples without tests

### Coverage Goals

| Category           | Target | Current            |
| ------------------ | ------ | ------------------ |
| Variable Coverage  | 80%+   | Check with script  |
| Output Validation  | 80%+   | Check with script  |
| Example Coverage   | 100%   | Check with script  |

### Improving Coverage

**To improve variable coverage:**

1. Add tests in `variable_combinations.tftest.hcl`
2. Create examples that exercise edge cases
3. Test different configuration combinations

**To improve output coverage:**

1. Add assertions to `outputs_validation.tftest.hcl`
2. Validate output formats (ARNs, URLs, etc.)
3. Check output relationships (e.g., URL contains DNS name)

**To improve example coverage:**

1. Create test file for each example: `tests/examples_<name>.tftest.hcl`
2. Each test should validate example deploys successfully

### Coverage Report Example

```text
Variable Coverage:              40%
Output Validation Coverage:     28%
Example Test Coverage:         100%

Overall Assessment: FAIR (56%)

Recommendations:
• Add output validation assertions
• Test more variable combinations
• Validate critical behaviors
```

### Understanding Coverage Limitations

⚠️ **Important:** These metrics use **static analysis** (text pattern matching), not runtime instrumentation like traditional code coverage tools.

**What each metric actually measures:**

| Metric                 | What It Checks                         | What It Does NOT Check                             |
| ---------------------- | -------------------------------------- | -------------------------------------------------- |
| **Resource Coverage**  | Resources defined in module            | If all resources are actually created in tests     |
| **Variable Coverage**  | If variable name appears in tests      | If tested with meaningful different values         |
| **Output Coverage**    | If output has an assertion             | Quality or comprehensiveness of assertion          |
| **Example Coverage**   | If test file exists                    | If test runs successfully or uses `apply`          |

**Examples of limitations:**

```hcl
# FALSE POSITIVE: Variable "tested" but only uses default
module "Keycloak" {
  db_instance_class = var.db_instance_class  # default only
}
# Coverage: ✅ 84%  Reality: ❌ Not really tested

# WEAK ASSERTION: Output "validated" but only checks existence
assert {
  condition = output.url != ""
}
# Coverage: ✅ 52%  Reality: 🤷 Minimal validation

# CONDITIONAL RESOURCE: Counted but may not be tested
resource "aws_lb_listener" "https" {
  count = var.certificate_arn != "" ? 1 : 0
}
# Coverage: ✅ Counted  Reality: ❌ Needs certificate test
```

**How to verify real coverage:**

1. **Read test files** - Check actual variable values and assertions
2. **Run tests** - `terraform test -verbose` shows what's created
3. **Review plans** - `terraform plan` in examples shows resources
4. **Manual testing** - Deploy to test AWS account for critical paths

**Use coverage metrics for:**

- ✅ Finding completely untested areas
- ✅ Tracking improvement over time
- ✅ Identifying missing test files

**Don't rely on them for:**

- ❌ Proof of correctness
- ❌ Measure of test quality
- ❌ Replacement for actual testing

## Best Practices

1. **Keep examples simple**: Each example should test one feature or use case
2. **Use defaults**: All variables should have sensible defaults
3. **Add assertions**: Validate critical outputs and behaviors
4. **Test incrementally**: Start with plan-only tests before full apply tests
5. **Clean up resources**: Never leave test resources running
6. **Monitor costs**: Set up billing alerts for test accounts
7. **Use descriptive names**: Test names should clearly indicate what they validate
8. **Measure coverage**: Run coverage script regularly to track progress
9. **Validate formats**: Use regex in assertions to validate ARN/URL formats
10. **Test combinations**: Use plan-only tests to validate variable combinations

## References

- [Terraform Testing Documentation](https://developer.hashicorp.com/terraform/language/tests)
- [AWS VPC Module Tests](https://github.com/aws-ia/terraform-aws-vpc/tree/main/tests) (our reference)
- [Terraform Test Assertions](https://developer.hashicorp.com/terraform/language/tests#assertions)

## Support

For issues or questions:

1. Check test output for error messages
2. Review CloudWatch logs for ECS/RDS errors
3. Verify AWS permissions and credentials
4. Open an issue in the repository
