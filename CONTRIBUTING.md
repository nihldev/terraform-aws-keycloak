# Contributing to Terraform AWS Keycloak

Thank you for contributing! This guide will help you get started with development.

## Prerequisites

- [mise](https://mise.jdx.dev/) - Runtime version manager
- [Git](https://git-scm.com/) - Version control
- [AWS CLI](https://aws.amazon.com/cli/) - For testing deployments (optional)

## Getting Started

### 1. Clone the Repository

```bash
git clone <repository-url>
cd terraform-aws-keycloak
```

### 2. Install Tools with mise

mise will automatically install all required tools defined in `mise.toml`:

```bash
mise install
```

This installs:

- **Terraform** - Infrastructure as code
- **pre-commit** - Git hook framework
- **tflint** - Terraform linter
- **trivy** - Security scanner
- **Terraform-docs** - Documentation generator
- **taplo** - TOML formatter and linter
- **markdownlint-cli** - Markdown linter
- **Python 3.11** - Required for SES SMTP password derivation and linting tools
- **ruff** - Python linter and formatter
- **basedpyright** - Python type checker

**Important:** The `post_install` hook will automatically:

- Initialize tflint plugins
- Install pre-commit hooks in your local repository

### 3. Verify Setup

Check that all tools are installed:

```bash
mise list
```

## Development Workflow

### Pre-push Hooks

Pre-push hooks run automatically when you push to the remote repository and will:

**Terraform:**

- Format Terraform code (`terraform fmt`)
- Validate Terraform syntax (`terraform validate`)
- Run security checks (`trivy`)
- Lint code (`tflint`)
- Update documentation (`terraform-docs`)

**TOML:**

- Validate TOML syntax (`check-toml`)
- Format TOML files (`taplo format`)
- Lint TOML files (`taplo lint`)

**Markdown:**

- Lint and fix markdown files (`markdownlint`)
- Apply consistent formatting

**General:**

- Check for large files, merge conflicts, trailing whitespace
- Detect private keys and AWS credentials
- Ensure files end with newlines

The hooks are automatically installed by mise as pre-push hooks. No manual setup required!

**Why pre-push instead of pre-commit?**

- Faster development workflow - checks run before push, not on every commit
- Still catches issues before they reach the remote repository
- Run checks manually anytime with `mise run check`

### Running Checks Manually

```bash
# Run all pre-push checks on all files
mise run check

# Format all Terraform files
mise run fmt

# Format all TOML files
mise run fmt-toml

# Format all Markdown files
mise run fmt-md

# Format all files (Terraform, TOML, Markdown)
mise run fmt-all

# Lint TOML files
mise run lint-toml

# Lint Markdown files
mise run lint-md

# Validate all Terraform configurations
mise run validate
```

### Making Changes

1. **Create a branch:**

   ```bash
   git checkout -b feature/my-new-feature
   ```

2. **Make your changes:**
   - Edit Terraform files
   - Update documentation in README.md
   - Add examples if applicable

3. **Commit your changes:**

   ```bash
   git add .
   git commit -m "feat: add new feature"
   ```

4. **Push your branch:**

   ```bash
   git push origin feature/my-new-feature
   ```

   Pre-push hooks will run automatically. If they fail:
   - Review the output for errors
   - Fix any issues
   - Commit the fixes: `git add . && git commit -m "fix: address validation issues"`
   - Push again

### Skipping Hooks (Not Recommended)

If you need to skip pre-push hooks (e.g., work in progress):

```bash
git push --no-verify
```

**Note:** Use this sparingly. All pushes to main should pass validation checks.

## Code Standards

### Terraform Style

- Use `terraform fmt` for formatting (enforced by pre-commit)
- Follow [HashiCorp's style guide](https://developer.hashicorp.com/terraform/language/style)
- Use meaningful variable and resource names
- Add descriptions to all variables and outputs

### Module Structure

```text
modules/<module-name>/
├── versions.tf      # Provider requirements
├── variables.tf     # Input variables
├── outputs.tf       # Output values
├── <resource>.tf    # Resource definitions (e.g., ecs.tf, rds.tf)
└── README.md        # Module documentation
```

### Documentation

- Every module must have a comprehensive README.md
- Use `terraform-docs` to generate input/output tables (done automatically)
- Include usage examples
- Document prerequisites and requirements
- Explain important design decisions

### Naming Conventions

**Resources:**

```hcl
resource "aws_ecs_cluster" "keycloak" {
  name = "${var.name}-keycloak-${var.environment}"
}
```

**Variables:**

- Use descriptive names: `db_instance_class` not `db_class`
- Use underscores for multi-word names
- Provide clear descriptions
- Set sensible defaults where possible

**Tags:**

```hcl
tags = merge(
  var.tags,
  {
    Name        = "${var.name}-${var.environment}"
    Environment = var.environment
  }
)
```

### TOML Style

- Use `taplo format` for formatting (enforced by pre-push hooks)
- Organize sections logically with blank lines between groups
- Use comments to explain complex configurations
- Keep arrays and inline tables readable

**Example (mise.toml):**

```toml
[tools]
# Infrastructure as Code
terraform = "1.14.0"
tflint = "latest"

# Code Quality
pre-commit = "latest"

[tasks.check]
description = "Run pre-commit checks on all files"
run = "pre-commit run --all-files"
```

### Markdown Style

- Use `markdownlint` for linting (enforced by pre-push hooks)
- Follow consistent heading hierarchy (don't skip levels)
- Use ATX-style headings (`#` prefix)
- Use dash (`-`) for unordered lists
- Specify language for code blocks
- Use meaningful alt text for images
- Keep lines readable (no hard line length limit)

**Example:**

```markdown
# Module Name

## Overview

Brief description here.

## Usage

bash
terraform init


### Configuration

- Use descriptive variable names
- Provide examples
```

## Testing

### Local Testing

1. Navigate to the example directory:

   ```bash
   cd examples/complete
   ```

2. Create a test configuration:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with test values
   ```

3. Initialize and plan:

   ```bash
   terraform init
   terraform plan
   ```

4. (Optional) Apply to test in AWS:

   ```bash
   terraform apply
   ```

5. Clean up:

   ```bash
   terraform destroy
   ```

### Validation Tests

Run validation on all modules:

```bash
mise run validate
```

This will:

- Initialize each module
- Run `terraform validate`
- Report any syntax or configuration errors

## Troubleshooting

### Pre-push hooks not running

If hooks aren't running automatically on push:

```bash
# Reinstall hooks
pre-commit uninstall
pre-commit install --hook-type pre-push --install-hooks

# Verify installation
pre-commit run --hook-stage push --all-files
```

### tflint errors

If tflint fails to initialize:

```bash
# Manually initialize tflint
tflint --init

# Run tflint
tflint --recursive
```

### mise not finding tools

If mise can't find installed tools:

```bash
# Reinstall all tools
mise install

# Check mise status
mise doctor
```

### Terraform validation fails

Common issues:

- Missing required providers in `versions.tf`
- Invalid variable references
- Circular dependencies

Run validation with verbose output:

```bash
terraform validate
```

## Security

### Secrets and Credentials

- **NEVER** commit secrets, credentials, or sensitive data
- Use AWS Secrets Manager for sensitive values
- The pre-push hooks check for AWS credentials and private keys
- Review `.gitignore` to ensure sensitive files are excluded

### Security Scanning

All code is automatically scanned with multiple tools on push:

**Trivy** - Security scanner (all severities)

```bash
trivy config --severity LOW,MEDIUM,HIGH,CRITICAL .
```

**Conftest/OPA** - Custom policy validation

```bash
conftest test --policy policy/ modules/
```

Address HIGH or CRITICAL issues before pushing.

## Commit Message Format

Use conventional commits format:

```text
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples:**

```text
feat(Keycloak): add support for custom domains

fix(Keycloak): correct security group egress rules

docs(Keycloak): update usage examples

chore: update pre-commit hooks
```

## Automated Quality Checks

This repository uses comprehensive automated checks to catch issues before code review. All checks run automatically as **pre-push hooks** when you push code.

### What Gets Checked Automatically

| Check | What It Catches | Auto-Fix | Tool |
| ----- | --------------- | -------- | ---- |
| **Terraform Format** | Inconsistent code formatting | ✅ Yes | terraform fmt |
| **Terraform Validate** | Syntax errors, invalid references | ❌ No | terraform validate |
| **TFLint** | Deprecated resources, naming violations, undocumented variables | ❌ No | tflint |
| **Trivy** | Security issues, missing encryption, public resources | ❌ No | trivy |
| **OPA Policies** | Keycloak-specific config issues | ❌ No | conftest |
| **tfvars Coverage** | Missing variable examples | ❌ No | custom script |
| **Markdown Lint** | Markdown formatting issues | ✅ Yes | markdownlint |
| **TOML Format** | TOML syntax and style | ✅ Yes | taplo |
| **Secret Detection** | AWS credentials, private keys | ❌ No | pre-commit |

### OPA/Conftest Policies (Keycloak-Specific)

This repository uses Open Policy Agent (OPA) policies via Conftest for application-specific validations that standard linters can't catch.

**Location**: `policy/keycloak.rego`

**What it checks**:

- Multi-instance cache configuration (prevents cache inconsistencies)
- Keycloak hostname strict backchannel settings (prevents health check failures)
- ECS deployment circuit breakers (enables automatic rollback)
- ALB access logging (security audit trails)
- KMS key usage (customer-managed encryption)
- Database connection pool configuration

**Run manually**:

```bash
conftest test --policy policy/ modules/keycloak/
```

**Writing custom policies**:

```rego
package main

import rego.v1

deny contains msg if {
    some resource in input.resource.aws_xxx
    not meets_requirement(resource)
    msg := "Your error message here"
}
```

### tfvars.example Coverage

A custom script validates that all module variables are documented in `Terraform.tfvars.example`:

```bash
./scripts/check-tfvars-coverage.sh
```

This ensures users have examples for all configuration options.

### What Automation Can't Catch

Some issues require human judgment and code review:

| Issue | Why Manual Review Needed |
| ----- | ------------------------ |
| Keycloak startup mode | Requires understanding of deployment lifecycle and database initialization |
| Performance tuning | Workload-specific decisions (connection pools, task sizing) |
| Architecture trade-offs | Context-dependent (JDBC_PING vs AWS_PING, cache strategies) |
| Documentation quality | Subjective: clarity, completeness, audience understanding |
| Security group egress rules | Requires understanding application network requirements |

### Bypassing Specific Checks

If a check incorrectly flags valid code, document why it's safe and suppress:

**Trivy:**

```hcl
#trivy:ignore:AVD-AWS-xxxx
resource "aws_xxx" "example" {
  # Reason: Explain why this is intentional/safe
}
```

Note: Legacy `#tfsec:ignore` comments are also supported by Trivy.

**TFLint:**

```hcl
# tflint-ignore: rule_name
resource "aws_xxx" "example" {
  # Reason: Explain why this exception is needed
}
```

## Getting Help

- Check module README.md files for documentation
- Review examples in `examples/` directory
- Open an issue for bugs or feature requests
- Review existing issues and pull requests
- Read policy documentation in `policy/` directory

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT License).
