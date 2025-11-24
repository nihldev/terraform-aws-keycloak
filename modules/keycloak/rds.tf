#######################
# Database Credentials
#######################

resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "random_password" "keycloak_admin_password" {
  length  = 32
  special = true
}

#######################
# DB Subnet Group
#######################

resource "aws_db_subnet_group" "keycloak" {
  name       = "${var.name}-keycloak-${var.environment}"
  subnet_ids = var.private_subnet_ids

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-${var.environment}"
      Environment = var.environment
    }
  )
}

#######################
# Security Group - RDS
#######################

resource "aws_security_group" "rds" {
  name_prefix = "${var.name}-keycloak-rds-${var.environment}-"
  description = "Security group for Keycloak RDS instance"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-rds-${var.environment}"
      Environment = var.environment
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "rds_ingress_from_ecs" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = aws_security_group.rds.id
  description              = "Allow PostgreSQL access from ECS tasks"
}

# RDS egress rule for stateful connection handling
# Note: This egress rule is technically not required for RDS as stateful security groups
# automatically allow response traffic. However, it's kept for explicit clarity and
# to prevent potential issues with connection tracking edge cases.
# RDS never initiates outbound connections in this configuration.
#tfsec:ignore:aws-ec2-no-public-egress-sgr
resource "aws_security_group_rule" "rds_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
  description       = "Allow responses to established connections (stateful)"
}

#######################
# RDS Instance
#######################

resource "aws_db_instance" "keycloak" {
  identifier     = "${var.name}-keycloak-${var.environment}"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.db_kms_key_id != "" ? var.db_kms_key_id : null

  db_name  = "keycloak"
  username = "keycloak"
  password = random_password.db_password.result

  multi_az               = var.multi_az
  db_subnet_group_name   = aws_db_subnet_group.keycloak.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # tfsec:ignore:aws-rds-specify-backup-retention Backup retention is configurable with validation ensuring minimum 7 days
  backup_retention_period = var.db_backup_retention_period
  backup_window           = var.db_backup_window
  maintenance_window      = var.db_maintenance_window

  deletion_protection       = var.db_deletion_protection
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${var.name}-keycloak-${var.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # IAM database authentication
  iam_database_authentication_enabled = var.db_iam_database_authentication_enabled

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.db_kms_key_id != "" ? var.db_kms_key_id : null
  performance_insights_retention_period = var.db_performance_insights_retention_period

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-${var.environment}"
      Environment = var.environment
    }
  )

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier
    ]
  }
}

#######################
# Secrets Manager
#######################

resource "aws_secretsmanager_secret" "keycloak_db" {
  name_prefix             = "${var.name}-keycloak-db-${var.environment}-"
  description             = "Keycloak database credentials"
  recovery_window_in_days = 7
  kms_key_id              = var.secrets_kms_key_id != "" ? var.secrets_kms_key_id : null

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-db-${var.environment}"
      Environment = var.environment
    }
  )
}

resource "aws_secretsmanager_secret_version" "keycloak_db" {
  secret_id = aws_secretsmanager_secret.keycloak_db.id
  secret_string = jsonencode({
    username = aws_db_instance.keycloak.username
    password = random_password.db_password.result
    host     = aws_db_instance.keycloak.address
    port     = aws_db_instance.keycloak.port
    dbname   = aws_db_instance.keycloak.db_name
  })
}

resource "aws_secretsmanager_secret" "keycloak_admin" {
  name_prefix             = "${var.name}-keycloak-admin-${var.environment}-"
  description             = "Keycloak admin credentials"
  recovery_window_in_days = 7
  kms_key_id              = var.secrets_kms_key_id != "" ? var.secrets_kms_key_id : null

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-admin-${var.environment}"
      Environment = var.environment
    }
  )
}

resource "aws_secretsmanager_secret_version" "keycloak_admin" {
  secret_id = aws_secretsmanager_secret.keycloak_admin.id
  secret_string = jsonencode({
    username = var.keycloak_admin_username
    password = random_password.keycloak_admin_password.result
  })
}
