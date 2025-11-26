#######################
# SES Email Integration
# Optional: Enable with enable_ses = true
#######################

#######################
# SES Domain Identity
#######################

resource "aws_ses_domain_identity" "keycloak" {
  count  = var.enable_ses ? 1 : 0
  domain = var.ses_domain
}

#######################
# SES Domain DKIM
# Creates DKIM tokens for email authentication
#######################

resource "aws_ses_domain_dkim" "keycloak" {
  count  = var.enable_ses ? 1 : 0
  domain = aws_ses_domain_identity.keycloak[0].domain
}

#######################
# Route53 Records for SES Verification (Optional)
# Only created if route53_zone_id is provided
#######################

# Domain verification TXT record
resource "aws_route53_record" "ses_verification" {
  count   = var.enable_ses && var.ses_route53_zone_id != "" ? 1 : 0
  zone_id = var.ses_route53_zone_id
  name    = "_amazonses.${var.ses_domain}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.keycloak[0].verification_token]
}

# DKIM CNAME records
resource "aws_route53_record" "ses_dkim" {
  count   = var.enable_ses && var.ses_route53_zone_id != "" ? 3 : 0
  zone_id = var.ses_route53_zone_id
  name    = "${aws_ses_domain_dkim.keycloak[0].dkim_tokens[count.index]}._domainkey.${var.ses_domain}"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_ses_domain_dkim.keycloak[0].dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# Wait for domain verification (only if Route53 records are managed)
resource "aws_ses_domain_identity_verification" "keycloak" {
  count  = var.enable_ses && var.ses_route53_zone_id != "" ? 1 : 0
  domain = aws_ses_domain_identity.keycloak[0].id

  depends_on = [aws_route53_record.ses_verification]
}

#######################
# SES Email Identity (Optional)
# For testing without domain verification
#######################

resource "aws_ses_email_identity" "keycloak" {
  count = var.enable_ses && var.ses_email_identity != "" ? 1 : 0
  email = var.ses_email_identity
}

#######################
# IAM User for SMTP Credentials
# SES SMTP requires IAM user credentials (not role credentials)
#######################

resource "aws_iam_user" "ses_smtp" {
  count = var.enable_ses ? 1 : 0
  name  = "${var.name}-keycloak-ses-${var.environment}"
  path  = "/system/"

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-ses-${var.environment}"
      Environment = var.environment
      Purpose     = "SES SMTP for Keycloak"
    }
  )
}

# IAM policy for sending emails
data "aws_iam_policy_document" "ses_send" {
  count = var.enable_ses ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]

    resources = ["*"]

    # Restrict to sending from verified domain/email
    condition {
      test     = "StringLike"
      variable = "ses:FromAddress"
      values   = var.ses_email_identity != "" ? [var.ses_email_identity] : ["*@${var.ses_domain}"]
    }
  }
}

resource "aws_iam_user_policy" "ses_smtp" {
  count  = var.enable_ses ? 1 : 0
  name   = "ses-send-email"
  user   = aws_iam_user.ses_smtp[0].name
  policy = data.aws_iam_policy_document.ses_send[0].json
}

# Create IAM access key for SMTP
resource "aws_iam_access_key" "ses_smtp" {
  count = var.enable_ses ? 1 : 0
  user  = aws_iam_user.ses_smtp[0].name
}

#######################
# SMTP Password Derivation
#
# AWS SES SMTP does NOT accept raw IAM credentials. The SMTP password must be
# derived from the IAM secret key using AWS's algorithm. This module automatically
# derives the password using an external Python script.
#
# See: https://docs.aws.amazon.com/ses/latest/dg/smtp-credentials.html
#
# Requirements: Python 3.x must be available on the machine running Terraform.
#######################

data "external" "ses_smtp_password" {
  count   = var.enable_ses ? 1 : 0
  program = ["python3", "${path.module}/scripts/derive-ses-smtp-password.py"]

  query = {
    secret_key = aws_iam_access_key.ses_smtp[0].secret
    region     = data.aws_region.current.name
  }
}

locals {
  # SES SMTP endpoint for the current region
  ses_smtp_endpoint = var.enable_ses ? "email-smtp.${data.aws_region.current.name}.amazonaws.com" : ""

  # Derived SMTP password (automatically computed from IAM secret key)
  ses_smtp_password = var.enable_ses ? data.external.ses_smtp_password[0].result.smtp_password : ""

  # SMTP credentials storage
  ses_smtp_credentials = var.enable_ses ? {
    smtp_host     = local.ses_smtp_endpoint
    smtp_port     = 587
    smtp_username = aws_iam_access_key.ses_smtp[0].id
    smtp_password = local.ses_smtp_password
    from_email    = var.ses_from_email != "" ? var.ses_from_email : "noreply@${var.ses_domain}"
    region        = data.aws_region.current.name
  } : {}
}

#######################
# Secrets Manager for SMTP Credentials
#######################

resource "aws_secretsmanager_secret" "ses_smtp" {
  count       = var.enable_ses ? 1 : 0
  name_prefix = "${var.name}-keycloak-ses-${var.environment}-"
  description = "SES SMTP credentials for Keycloak email"

  kms_key_id = var.secrets_kms_key_id

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-ses-${var.environment}"
      Environment = var.environment
    }
  )
}

resource "aws_secretsmanager_secret_version" "ses_smtp" {
  count     = var.enable_ses ? 1 : 0
  secret_id = aws_secretsmanager_secret.ses_smtp[0].id
  secret_string = jsonencode({
    smtp_host     = local.ses_smtp_credentials.smtp_host
    smtp_port     = local.ses_smtp_credentials.smtp_port
    smtp_username = local.ses_smtp_credentials.smtp_username
    smtp_password = local.ses_smtp_credentials.smtp_password
    from_email    = local.ses_smtp_credentials.from_email
    region        = local.ses_smtp_credentials.region
  })
}

#######################
# SES Configuration Set (Optional)
# For tracking email delivery metrics
#######################

resource "aws_ses_configuration_set" "keycloak" {
  count = var.enable_ses && var.ses_configuration_set_enabled ? 1 : 0
  name  = "${var.name}-keycloak-${var.environment}"

  reputation_metrics_enabled = true
  sending_enabled            = true

  delivery_options {
    tls_policy = "Require"
  }
}

# CloudWatch destination for email events
resource "aws_ses_event_destination" "cloudwatch" {
  count                  = var.enable_ses && var.ses_configuration_set_enabled ? 1 : 0
  name                   = "cloudwatch-metrics"
  configuration_set_name = aws_ses_configuration_set.keycloak[0].name
  enabled                = true

  matching_types = [
    "send",
    "reject",
    "bounce",
    "complaint",
    "delivery",
    "open",
    "click",
    "renderingFailure",
  ]

  cloudwatch_destination {
    default_value  = "default"
    dimension_name = "ses:source-ip"
    value_source   = "messageTag"
  }
}
