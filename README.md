# Terraform AWS Keycloak

[![Terraform Registry](https://img.shields.io/badge/Terraform%20Registry-nihldev%2Fkeycloak%2Faws-blue)](https://registry.terraform.io/modules/nihldev/keycloak/aws/latest)

Terraform module for deploying [Keycloak](https://www.keycloak.org/) identity and access management on AWS using ECS Fargate, with flexible database options and production-ready defaults.

## Features

- **Serverless Containers**: ECS Fargate with CPU/memory auto-scaling
- **Flexible Databases**: RDS PostgreSQL, Aurora Provisioned, or Aurora Serverless v2
- **High Availability**: Multi-AZ deployment with automatic failover
- **Security**: Secrets Manager, encrypted storage, least-privilege IAM
- **Monitoring**: CloudWatch logs, metrics, alarms, and Container Insights
- **Email Integration**: Optional Amazon SES for notifications
- **Custom Images**: ECR support for themes and extensions

## Quick Start

```hcl
module "keycloak" {
  source  = "nihldev/keycloak/aws"
  version = "~> 1.0"

  name        = "myapp"
  environment = "prod"

  vpc_id             = "vpc-xxxxx"
  public_subnet_ids  = ["subnet-xxxxx", "subnet-yyyyy"]
  private_subnet_ids = ["subnet-aaaaa", "subnet-bbbbb"]

  multi_az      = true
  desired_count = 2
}
```

For detailed configuration options, see the [module documentation](modules/keycloak/README.md).

## Examples

| Example | Description | Database | Est. Cost |
| ------- | ----------- | -------- | --------- |
| [basic](examples/basic/) | Minimal dev/test deployment | RDS PostgreSQL | ~$50-70/mo |
| [complete](examples/complete/) | Production-ready with VPC and HTTPS | RDS PostgreSQL | ~$80-400/mo |
| [aurora-provisioned](examples/aurora-provisioned/) | High availability with read replicas | Aurora | ~$400-900/mo |
| [aurora-serverless](examples/aurora-serverless/) | Auto-scaling for variable workloads | Aurora Serverless v2 | ~$40-800/mo |
| [ses-email](examples/ses-email/) | With SES email integration | RDS PostgreSQL | ~$80-400/mo |

Each example directory contains complete Terraform configurations with detailed README files.

## Usage with Terragrunt

Reference this module in your `infra-live` repository:

```hcl
# infra-live/prod/us-east-1/keycloak/terragrunt.hcl
terraform {
  source = "tfr:///nihldev/keycloak/aws?version=~>1.0"
}

inputs = {
  name        = "myapp"
  environment = "prod"

  vpc_id             = dependency.vpc.outputs.vpc_id
  public_subnet_ids  = dependency.vpc.outputs.public_subnets
  private_subnet_ids = dependency.vpc.outputs.private_subnets

  multi_az      = true
  desired_count = 2
}
```

## Documentation

- **[Module Documentation](modules/keycloak/README.md)** - Full configuration reference, database options, architecture
- **[Examples](examples/)** - Complete working configurations for different use cases
- **[Tests](tests/README.md)** - Terraform test framework documentation
- **[Contributing](CONTRIBUTING.md)** - Development setup, code standards, testing

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.
