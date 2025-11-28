# Keycloak with SES Email Integration

This example deploys Keycloak with AWS SES integration for sending emails
(password reset, email verification, etc.).

## Features

- Basic Keycloak deployment with minimal resources
- SES domain identity with DKIM authentication
- Automatic SMTP password derivation
- Optional Route53 DNS record management
- Optional SES Configuration Set for email tracking

## Usage

```hcl
module "Keycloak" {
  source = "../../modules/keycloak"

  name        = "my-Keycloak"
  environment = "dev"

  # ... networking config ...

  # SES Configuration
  enable_ses  = true
  ses_domain  = "example.com"

  # Optional: Auto-create DNS records
  ses_route53_zone_id = "Z1234567890ABC"

  # Optional: Email tracking
  ses_configuration_set_enabled = true
}
```

## SES Sandbox Mode

By default, SES starts in sandbox mode which limits email sending to verified
addresses only. To send emails to any address:

1. Go to AWS SES Console
2. Request production access
3. Wait for AWS approval (usually 24-48 hours)

## DNS Records

If `ses_route53_zone_id` is provided, DNS records are created automatically.
Otherwise, you must manually create:

1. **TXT record** for domain verification
2. **CNAME records** (3) for DKIM authentication

The required records are available in the `ses_dns_records_required` output.

## SMTP Credentials

SMTP credentials are automatically stored in Secrets Manager with the derived
SMTP password (not the raw IAM secret key). Retrieve them with:

```bash
aws secretsmanager get-secret-value \
  --secret-id <ses_smtp_credentials_secret_id> \
  --query SecretString --output text | jq
```

## Inputs

| Name | Description | Type | Default |
| ---- | ----------- | ---- | ------- |
| enable_ses | Enable SES email integration | bool | true |
| ses_domain | Domain for sending emails | string | - |
| ses_email_identity | Specific email to verify (optional) | string | "" |
| ses_from_email | From address for emails | string | "noreply@{domain}" |
| ses_route53_zone_id | Route53 zone for auto DNS records | string | "" |
| ses_configuration_set_enabled | Enable email tracking | bool | false |

## Outputs

| Name | Description |
| ---- | ----------- |
| ses_smtp_endpoint | SMTP endpoint for Keycloak configuration |
| ses_smtp_credentials_secret_id | Secret ID containing SMTP credentials |
| ses_from_email | Configured From email address |
| ses_dns_records_required | DNS records to create (if not using Route53) |
