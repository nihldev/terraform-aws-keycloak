#######################
# ECS Task Execution Role
# Used by ECS to pull images and publish logs
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
