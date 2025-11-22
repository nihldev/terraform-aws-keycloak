#######################
# ECS Task Execution Role
# Used by ECS to pull images and publish logs
#######################
#
# IMPORTANT: KMS Key Permissions
# If you provide custom KMS keys via db_kms_key_id or secrets_kms_key_id variables,
# ensure your KMS key policy grants the following permissions:
#
# For db_kms_key_id (RDS encryption):
# - kms:Decrypt, kms:DescribeKey, kms:CreateGrant to this execution role
#
# For secrets_kms_key_id (Secrets Manager encryption):
# - kms:Decrypt, kms:DescribeKey to this execution role
#
# Example KMS key policy statement:
# {
#   "Sid": "Allow ECS task execution role to decrypt",
#   "Effect": "Allow",
#   "Principal": {
#     "AWS": "arn:aws:iam::ACCOUNT_ID:role/EXECUTION_ROLE_NAME"
#   },
#   "Action": [
#     "kms:Decrypt",
#     "kms:DescribeKey",
#     "kms:CreateGrant"
#   ],
#   "Resource": "*",
#   "Condition": {
#     "StringEquals": {
#       "kms:ViaService": [
#         "secretsmanager.REGION.amazonaws.com",
#         "rds.REGION.amazonaws.com"
#       ]
#     }
#   }
# }
#######################

data "aws_iam_policy_document" "ecs_task_execution_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name_prefix        = "${var.name}-keycloak-exec-${var.environment}-"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role.json

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-execution-${var.environment}"
      Environment = var.environment
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow reading secrets from Secrets Manager
data "aws_iam_policy_document" "ecs_task_execution_secrets" {
  statement {
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
    ]

    resources = [
      aws_secretsmanager_secret.keycloak_db.arn,
      aws_secretsmanager_secret.keycloak_admin.arn,
    ]
  }
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name_prefix = "secrets-access-"
  role        = aws_iam_role.ecs_task_execution.id
  policy      = data.aws_iam_policy_document.ecs_task_execution_secrets.json
}

#######################
# ECS Task Role
# Used by the application running in the container
#######################

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ecs_task" {
  name_prefix        = "${var.name}-keycloak-task-${var.environment}-"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-task-${var.environment}"
      Environment = var.environment
    }
  )
}

# Allow reading secrets at runtime if needed
data "aws_iam_policy_document" "ecs_task_secrets" {
  statement {
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
    ]

    resources = [
      aws_secretsmanager_secret.keycloak_db.arn,
      aws_secretsmanager_secret.keycloak_admin.arn,
    ]
  }
}

resource "aws_iam_role_policy" "ecs_task_secrets" {
  name_prefix = "secrets-access-"
  role        = aws_iam_role.ecs_task.id
  policy      = data.aws_iam_policy_document.ecs_task_secrets.json
}

# Allow writing CloudWatch metrics (optional, for Keycloak metrics)
data "aws_iam_policy_document" "ecs_task_cloudwatch" {
  statement {
    effect = "Allow"

    actions = [
      "cloudwatch:PutMetricData",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["Keycloak/${var.environment}"]
    }
  }
}

resource "aws_iam_role_policy" "ecs_task_cloudwatch" {
  name_prefix = "cloudwatch-metrics-"
  role        = aws_iam_role.ecs_task.id
  policy      = data.aws_iam_policy_document.ecs_task_cloudwatch.json
}
