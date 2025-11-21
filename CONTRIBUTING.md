# Contributing to Infrastructure Modules

Thank you for contributing! This guide will help you get started with development.

## Prerequisites

- [mise](https://mise.jdx.dev/) - Runtime version manager
- [Git](https://git-scm.com/) - Version control
- [AWS CLI](https://aws.amazon.com/cli/) - For testing deployments (optional)

## Getting Started

### 1. Clone the Repository

```bash
git clone <repository-url>
cd infra-modules
```

### 2. Install Tools with mise

mise will automatically install all required tools defined in `mise.TOML`:

```bash
mise install
```

This installs:

- **Terraform** - Infrastructure as code
- **pre-commit** - Git hook framework
- **tflint** - Terraform linter
- **tfsec** - Security scanner
- **Terraform-docs** - Documentation generator
- **taplo** - TOML formatter and linter
- **markdownlint-cli** - Markdown linter

**Important:** The `post_install` hook will automatically:

- Initialize tflint plugins
- Install pre-commit hooks in your local repository

### 3. Verify Setup

Check that all tools are installed:

```bash
mise list
```

## Development Workflow

### Pre-commit Hooks

Pre-commit hooks run automatically on every commit and will:

**Terraform:**

- Format Terraform code (`Terraform fmt`)
- Validate Terraform syntax (`Terraform validate`)
- Run security checks (`tfsec`)
- Lint code (`tflint`)
- Update documentation (`Terraform-docs`)

**TOML:**

- Validate TOML syntax (`check-TOML`)
- Format TOML files (`taplo format`)
- Lint TOML files (`taplo lint`)

**Markdown:**

- Lint and fix markdown files (`markdownlint`)
- Apply consistent formatting

**General:**

- Check for large files, merge conflicts, trailing whitespace
- Detect private keys and AWS credentials
- Ensure files end with newlines

The hooks are automatically installed by mise. No manual setup required!

### Running Checks Manually

```bash
# Run all pre-commit checks on all files
mise run check

# Format all Terraform files
mise run fmt

# Format all TOML files
mise run fmt-TOML

# Format all Markdown files
mise run fmt-md

# Format all files (Terraform, TOML, Markdown)
mise run fmt-all

# Lint TOML files
mise run lint-TOML

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

   Pre-commit hooks will run automatically. If they fail:
   - Review the output for errors
   - Fix any issues
   - Stage the fixes: `git add .`
   - Commit again

4. **Push your branch:**

   ```bash
   git push origin feature/my-new-feature
   ```

### Skipping Hooks (Not Recommended)

If you need to skip pre-commit hooks (e.g., work in progress):

```bash
git commit --no-verify -m "WIP: incomplete feature"
```

**Note:** Use this sparingly. All commits to main should pass pre-commit checks.

## Code Standards

### Terraform Style

- Use `Terraform fmt` for formatting (enforced by pre-commit)
- Follow [HashiCorp's style guide](https://developer.hashicorp.com/terraform/language/style)
- Use meaningful variable and resource names
- Add descriptions to all variables and outputs

### Module Structure

```text
modules/<module-name>/
├── versions.tf      # Provider requirements
├── variables.tf     # Input variables
├── outputs.tf       # Output values
├── <resource>.tf    # Resource definitions (e.g., ECS.tf, RDS.tf)
└── README.md        # Module documentation
```

### Documentation

- Every module must have a comprehensive README.md
- Use `Terraform-docs` to generate input/output tables (done automatically)
- Include usage examples
- Document prerequisites and requirements
- Explain important design decisions

### Naming Conventions

**Resources:**

```hcl
resource "aws_ecs_cluster" "Keycloak" {
  name = "${var.name}-Keycloak-${var.environment}"
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

- Use `taplo format` for formatting (enforced by pre-commit)
- Organize sections logically with blank lines between groups
- Use comments to explain complex configurations
- Keep arrays and inline tables readable

**Example (mise.TOML):**

```toml
[tools]
# Infrastructure as Code
Terraform = "1.14.0"
tflint = "latest"

# Code Quality
pre-commit = "latest"

[tasks.check]
description = "Run pre-commit checks on all files"
run = "pre-commit run --all-files"
```

### Markdown Style

- Use `markdownlint` for linting (enforced by pre-commit)
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
Terraform init


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
   cp Terraform.tfvars.example Terraform.tfvars
   # Edit Terraform.tfvars with test values
   ```

3. Initialize and plan:

   ```bash
   Terraform init
   Terraform plan
   ```

4. (Optional) Apply to test in AWS:

   ```bash
   Terraform apply
   ```

5. Clean up:

   ```bash
   Terraform destroy
   ```

### Validation Tests

Run validation on all modules:

```bash
mise run validate
```

This will:

- Initialize each module
- Run `Terraform validate`
- Report any syntax or configuration errors

## Troubleshooting

### Pre-commit hooks not running

If hooks aren't running automatically:

```bash
# Reinstall hooks
pre-commit install --install-hooks

# Verify installation
pre-commit run --all-files
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
Terraform validate
```

## Security

### Secrets and Credentials

- **NEVER** commit secrets, credentials, or sensitive data
- Use AWS Secrets Manager for sensitive values
- The pre-commit hook checks for AWS credentials and private keys
- Review `.gitignore` to ensure sensitive files are excluded

### Security Scanning

All code is automatically scanned with `tfsec` on commit. Address any HIGH or CRITICAL issues before committing.

Run security scan manually:

```bash
tfsec .
```

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

## Getting Help

- Check module README.md files for documentation
- Review examples in `examples/` directory
- Open an issue for bugs or feature requests
- Review existing issues and pull requests

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT License).
