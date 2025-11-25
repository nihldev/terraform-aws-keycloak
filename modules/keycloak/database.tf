#######################
# Database Credentials
#######################

resource "random_password" "db_password" {
  length  = 32
  special = true
}

#######################
# Smart Defaults (Locals)
#######################

locals {
  # Smart default for Aurora replica count
  aurora_replicas = (
    var.aurora_replica_count != null
    ? var.aurora_replica_count
    : (var.multi_az ? 1 : 0)
  )

  # Smart default for Aurora backtrack window
  backtrack_window = (
    var.aurora_backtrack_window != null
    ? var.aurora_backtrack_window
    : (var.environment == "prod" ? 24 : 0)
  )

  # Smart default for Performance Insights retention
  pi_retention = (
    var.db_performance_insights_retention_period != null
    ? var.db_performance_insights_retention_period
    : (var.database_type == "aurora" && var.environment == "prod" ? 31 : 7)
  )

  # Cost warning for Aurora in non-prod
  cost_warning = (
    var.database_type != "rds" && var.environment != "prod"
    ? "💰 COST WARNING: Aurora costs ~2x standard RDS. Consider database_type='rds' for dev/test environments to reduce costs."
    : ""
  )
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
# Security Group - Database
#######################

resource "aws_security_group" "rds" {
  name_prefix = "${var.name}-keycloak-db-${var.environment}-"
  description = "Security group for Keycloak database (RDS/Aurora)"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-db-${var.environment}"
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

# Database egress rule for stateful connection handling
# Note: This egress rule is technically not required for databases as stateful security groups
# automatically allow response traffic. However, it's kept for explicit clarity and
# to prevent potential issues with connection tracking edge cases.
# Databases never initiate outbound connections in this configuration.
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
# RDS Instance (Standard PostgreSQL)
#######################

resource "aws_db_instance" "keycloak" {
  count = var.database_type == "rds" ? 1 : 0

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
  performance_insights_retention_period = local.pi_retention

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
# Aurora Cluster
#######################

resource "aws_rds_cluster" "keycloak" {
  count = contains(["aurora", "aurora-serverless"], var.database_type) ? 1 : 0

  cluster_identifier = "${var.name}-keycloak-${var.environment}"
  engine             = "aurora-postgresql"
  engine_version     = var.db_engine_version
  database_name      = "keycloak"
  master_username    = "keycloak"
  master_password    = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.keycloak.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Backup configuration
  # tfsec:ignore:aws-rds-specify-backup-retention Backup retention is configurable with validation ensuring minimum 7 days
  backup_retention_period      = var.db_backup_retention_period
  preferred_backup_window      = var.db_backup_window
  preferred_maintenance_window = var.db_maintenance_window

  # Encryption
  storage_encrypted = true
  kms_key_id        = var.db_kms_key_id != "" ? var.db_kms_key_id : null

  # Aurora-specific features
  backtrack_window = var.database_type == "aurora" ? local.backtrack_window : 0

  # Serverless v2 scaling configuration
  dynamic "serverlessv2_scaling_configuration" {
    for_each = var.database_type == "aurora-serverless" ? [1] : []

    content {
      min_capacity = var.db_capacity_min
      max_capacity = var.db_capacity_max
    }
  }

  # Deletion protection
  deletion_protection       = var.db_deletion_protection
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${var.name}-keycloak-${var.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Logging
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # IAM database authentication
  iam_database_authentication_enabled = var.db_iam_database_authentication_enabled

  tags = merge(
    var.tags,
    {
      Name         = "${var.name}-keycloak-${var.environment}"
      Environment  = var.environment
      DatabaseType = var.database_type
    }
  )

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier
    ]
  }
}

#######################
# Aurora Provisioned Instances
#######################

# Writer instance
resource "aws_rds_cluster_instance" "keycloak_writer" {
  count = var.database_type == "aurora" ? 1 : 0

  identifier         = "${var.name}-keycloak-${var.environment}-writer"
  cluster_identifier = aws_rds_cluster.keycloak[0].id
  instance_class     = var.db_instance_class
  engine             = "aurora-postgresql"

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.db_kms_key_id != "" ? var.db_kms_key_id : null
  performance_insights_retention_period = local.pi_retention

  # Auto minor version upgrades
  auto_minor_version_upgrade = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-${var.environment}-writer"
      Environment = var.environment
      Role        = "writer"
    }
  )
}

# Reader instances (count based on aurora_replica_count)
resource "aws_rds_cluster_instance" "keycloak_reader" {
  count = var.database_type == "aurora" ? local.aurora_replicas : 0

  identifier         = "${var.name}-keycloak-${var.environment}-reader-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.keycloak[0].id
  instance_class     = var.db_instance_class
  engine             = "aurora-postgresql"

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.db_kms_key_id != "" ? var.db_kms_key_id : null
  performance_insights_retention_period = local.pi_retention

  # Auto minor version upgrades
  auto_minor_version_upgrade = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-${var.environment}-reader-${count.index + 1}"
      Environment = var.environment
      Role        = "reader"
    }
  )
}

#######################
# Aurora Serverless v2 Instance
#######################

resource "aws_rds_cluster_instance" "keycloak_serverless" {
  count = var.database_type == "aurora-serverless" ? 1 : 0

  identifier         = "${var.name}-keycloak-${var.environment}-serverless"
  cluster_identifier = aws_rds_cluster.keycloak[0].id
  instance_class     = "db.serverless"
  engine             = "aurora-postgresql"

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = var.db_kms_key_id != "" ? var.db_kms_key_id : null
  performance_insights_retention_period = local.pi_retention

  # Auto minor version upgrades
  auto_minor_version_upgrade = true

  tags = merge(
    var.tags,
    {
      Name         = "${var.name}-keycloak-${var.environment}-serverless"
      Environment  = var.environment
      DatabaseType = "aurora-serverless"
    }
  )
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
    username = "keycloak"
    password = random_password.db_password.result
    host     = var.database_type == "rds" ? aws_db_instance.keycloak[0].address : aws_rds_cluster.keycloak[0].endpoint
    port     = var.database_type == "rds" ? aws_db_instance.keycloak[0].port : aws_rds_cluster.keycloak[0].port
    dbname   = "keycloak"
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
