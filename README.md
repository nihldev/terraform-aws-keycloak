# Terraform AWS Keycloak

[![Terraform Registry](https://img.shields.io/badge/Terraform%20Registry-nihldev%2Fkeycloak%2Faws-blue?logo=terraform)](https://registry.terraform.io/modules/nihldev/keycloak/aws/latest)
[![GitHub release](https://img.shields.io/github/v/release/nihldev/terraform-aws-keycloak?logo=github)](https://github.com/nihldev/terraform-aws-keycloak/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.14-purple?logo=terraform)](https://www.terraform.io/)
[![CI](https://github.com/nihldev/terraform-aws-keycloak/actions/workflows/terraform-tests.yml/badge.svg)](https://github.com/nihldev/terraform-aws-keycloak/actions/workflows/terraform-tests.yml)

Terraform module for deploying [Keycloak](https://www.keycloak.org/) identity and access management on AWS using ECS Fargate, with flexible database options and production-ready defaults.

> Deploy a production-ready Keycloak identity provider on AWS with a single module call. Supports RDS PostgreSQL, Aurora Provisioned, and Aurora Serverless v2 databases.

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
  version = "~> 0.1"

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

## Requirements

| Name                                                                           | Version |
| ------------------------------------------------------------------------------ | ------- |
| [Terraform](https://www.terraform.io/)                                         | >= 1.14 |
| [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)   | ~> 5.0  |

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

- Report bugs via [GitHub Issues](https://github.com/nihldev/terraform-aws-keycloak/issues)
- Ask questions in [GitHub Discussions](https://github.com/nihldev/terraform-aws-keycloak/discussions)
- Submit PRs for bug fixes and features

## License

MIT License - see [LICENSE](LICENSE) for details.

---

If you find this module helpful, please consider giving it a ⭐ on [GitHub](https://github.com/nihldev/terraform-aws-keycloak)!
