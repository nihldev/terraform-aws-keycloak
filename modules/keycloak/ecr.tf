#######################
# ECR Repository (Optional)
# Enable with create_ecr_repository = true
#######################

resource "aws_ecr_repository" "keycloak" {
  count = var.create_ecr_repository ? 1 : 0

  name                 = "${var.name}-keycloak-${var.environment}"
  image_tag_mutability = var.ecr_image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.ecr_scan_on_push
  }

  encryption_configuration {
    encryption_type = var.ecr_kms_key_id != "" ? "KMS" : "AES256"
    kms_key         = var.ecr_kms_key_id != "" ? var.ecr_kms_key_id : null
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-${var.environment}"
      Environment = var.environment
    }
  )
}

#######################
# ECR Lifecycle Policy
# Automatically clean up old images
#######################

resource "aws_ecr_lifecycle_policy" "keycloak" {
  count = var.create_ecr_repository ? 1 : 0

  repository = aws_ecr_repository.keycloak[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.ecr_image_retention_count} images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = var.ecr_image_tag_prefixes
          countType     = "imageCountMoreThan"
          countNumber   = var.ecr_image_retention_count
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

#######################
# ECR Repository Policy (Optional)
# Allow cross-account access if needed
#######################

resource "aws_ecr_repository_policy" "keycloak" {
  count = var.create_ecr_repository && length(var.ecr_allowed_account_ids) > 0 ? 1 : 0

  repository = aws_ecr_repository.keycloak[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountPull"
        Effect = "Allow"
        Principal = {
          AWS = [for account_id in var.ecr_allowed_account_ids : "arn:aws:iam::${account_id}:root"]
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

#######################
# Locals for Image URI
#######################

locals {
  # Determine the image to use:
  # 1. If keycloak_image is explicitly set, use it
  # 2. Otherwise, use the official Keycloak image
  #
  # Note: ECR repository URL is available as an output. To use your custom
  # image from ECR, set keycloak_image to "${ecr_repository_url}:your-tag"

  default_keycloak_image = "quay.io/keycloak/keycloak:${var.keycloak_version}"

  ecr_repository_url = var.create_ecr_repository ? aws_ecr_repository.keycloak[0].repository_url : ""

  keycloak_image = var.keycloak_image != "" ? var.keycloak_image : local.default_keycloak_image
}
