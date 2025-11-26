# Terraform AWS Keycloak

This repository contains a reusable Terraform module for deploying Keycloak on AWS.

## Available Modules

### Keycloak

Deploy Keycloak identity and access management system on AWS with ECS Fargate, RDS PostgreSQL, and Application Load Balancer.

**Features:**

- Serverless containers with auto-scaling
- Managed PostgreSQL database
- High availability support
- Built-in monitoring and alerting
- Production-ready security

**Documentation:** [modules/keycloak/README.md](modules/keycloak/README.md)

**Quick Start:**

```hcl
module "keycloak" {
  source = "git::https://github.com/nihldev/terraform-aws-keycloak.git//modules/keycloak?ref=v1.0.0"

  name        = "myapp"
  environment = "prod"

  vpc_id             = "vpc-xxxxx"
  public_subnet_ids  = ["subnet-xxxxx", "subnet-yyyyy"]
  private_subnet_ids = ["subnet-aaaaa", "subnet-bbbbb"]

  multi_az      = true
  desired_count = 3
}
```

## Usage with infra-live

Reference these modules in your `infra-live` repository:

```hcl
# infra-live/prod/us-east-1/keycloak/terragrunt.hcl
terraform {
  source = "git::https://github.com/nihldev/terraform-aws-keycloak.git//modules/keycloak?ref=v1.0.0"
}

inputs = {
  name        = "myapp"
  environment = "prod"

  vpc_id             = dependency.vpc.outputs.vpc_id
  public_subnet_ids  = dependency.vpc.outputs.public_subnets
  private_subnet_ids = dependency.vpc.outputs.private_subnets

  multi_az      = true
  desired_count = 3
}
```

## Development

### Prerequisites

- [mise](https://mise.jdx.dev/) - Runtime version manager
- AWS CLI configured (for testing deployments)

### Getting Started

1. Clone the repository:

   ```bash
   git clone <repository-url>
   cd terraform-aws-keycloak
   ```

2. Install development tools with mise:

   ```bash
   mise install
   ```

   This automatically installs:
   - Terraform
   - pre-commit framework (for pre-push hooks)
   - tflint (Terraform linter)
   - trivy (security scanner)
   - Terraform-docs (documentation generator)
   - taplo (TOML formatter and linter)
   - markdownlint-cli (Markdown linter)

3. Verify setup:

   ```bash
   mise list
   ```

The `post_install` hook automatically sets up pre-push hooks in your repository.

### Pre-push Hooks

Pre-push hooks run automatically when pushing to the remote repository and will:

- Format and validate Terraform code
- Run security checks with `trivy`
- Lint Terraform with `tflint`
- Format and lint TOML files with `taplo`
- Lint and fix Markdown files
- Update documentation automatically
- Check for secrets, large files, and other issues

Run checks manually:

```bash
# Run all checks on all files
mise run check

# Format Terraform files
mise run fmt

# Format TOML files
mise run fmt-toml

# Format Markdown files
mise run fmt-md

# Format all files (Terraform, TOML, Markdown)
mise run fmt-all

# Lint TOML files
mise run lint-toml

# Lint Markdown files
mise run lint-md

# Validate Terraform configurations
mise run validate
```

### Running Tests

We use Terraform's native testing framework for automated testing:

```bash
# Run all tests
terraform test

# Run specific test
terraform test ./tests/examples_basic.tftest.hcl

# Run with verbose output
terraform test -verbose

# Plan-only tests (fast, no AWS resources created)
terraform test ./tests/module_validation.tftest.hcl
```

See [tests/README.md](tests/README.md) for detailed testing documentation.

### Testing a Module Manually

1. Navigate to an example directory:

   ```bash
   cd examples/complete
   ```

2. Initialize Terraform:

   ```bash
   terraform init
   ```

3. Plan the deployment:

   ```bash
   terraform plan
   ```

4. Apply (optional):

   ```bash
   terraform apply
   ```

### Adding New Modules

1. Create a new directory under `modules/`:

   ```bash
   mkdir -p modules/new-module
   ```

2. Create the required files:
   - `versions.tf` - Provider requirements
   - `variables.tf` - Input variables
   - `outputs.tf` - Output values
   - `README.md` - Documentation
   - Resource files (e.g., `main.tf` or organized by service)

3. Follow best practices:
   - Use clear, descriptive variable names
   - Provide sensible defaults
   - Include comprehensive documentation
   - Add usage examples
   - Implement proper tagging

4. Create an example in `examples/`:

   ```bash
   mkdir -p examples/new-module-example
   ```

## Best Practices

### Module Design

- **Single Responsibility**: Each module should have a clear, focused purpose
- **Composability**: Modules should be easy to combine
- **Flexibility**: Provide variables for common customizations
- **Defaults**: Use sensible defaults for optional variables
- **Documentation**: Include comprehensive README with examples

### Naming Conventions

- Use lowercase with hyphens for resource names
- Prefix all resources with `var.name` and `var.environment`
- Use descriptive, consistent naming across modules

### Security

- Never hardcode credentials or sensitive data
- Use AWS Secrets Manager for secrets
- Enable encryption by default
- Follow principle of least privilege for IAM
- Implement proper network segmentation

### Versioning

- Use semantic versioning (MAJOR.MINOR.PATCH)
- Tag releases in Git
- Document breaking changes in release notes
- Maintain backwards compatibility when possible

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on:

- Development workflow
- Code standards
- Testing procedures
- Commit message format

## License

This repository is provided as-is under the MIT License.

## Support

For questions or issues:

- Check module documentation in `modules/*/README.md`
- Review examples in `examples/`
- Open an issue on GitHub
