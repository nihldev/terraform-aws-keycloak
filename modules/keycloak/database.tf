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
  # Database type helpers (single source of truth for type checks)
  is_rds               = var.database_type == "rds"
  is_aurora            = var.database_type == "aurora"
  is_aurora_serverless = var.database_type == "aurora-serverless"
  is_any_aurora        = contains(["aurora", "aurora-serverless"], var.database_type)

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
    : (local.is_aurora && var.environment == "prod" ? 31 : 7)
  )

  # Smart default for deletion protection (enabled in prod)
  deletion_protection = (
    var.db_deletion_protection != null
    ? var.db_deletion_protection
    : (var.environment == "prod")
  )

  # Cost warning for Aurora in non-prod
  cost_warning = (
    !local.is_rds && var.environment != "prod"
    ? "💰 COST WARNING: Aurora costs ~2x standard RDS. Consider database_type='rds' for dev/test environments to reduce costs."
    : ""
  )
}

#######################
# Cost Warning Check
# Surfaces warning during plan when Aurora is used in non-prod
# Requires Terraform >= 1.5.0 (check blocks)
#######################

check "aurora_cost_warning" {
  assert {
    condition     = local.is_rds || var.environment == "prod"
    error_message = "COST WARNING: Aurora (${var.database_type}) costs ~2x standard RDS. Consider database_type='rds' for ${var.environment} environment to reduce costs."
  }
}

check "multi_az_aurora_guidance" {
  assert {
    condition = !(
      var.multi_az == true &&
      local.is_any_aurora &&
      var.aurora_replica_count == null
    )
    error_message = <<-EOT
      NOTE: For Aurora, 'multi_az' provides a smart default for read replicas.
      Aurora storage is always replicated across 3 AZs automatically.

      For explicit control over Aurora HA, use 'aurora_replica_count' instead:
        aurora_replica_count = 1  # Creates 1 reader instance

      Current behavior: multi_az=true creates 1 reader instance by default.
    EOT
  }
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
# RDS Parameter Group
# Keycloak-optimized PostgreSQL settings
#######################

resource "aws_db_parameter_group" "keycloak" {
  count = local.is_rds ? 1 : 0

  name_prefix = "${var.name}-keycloak-${var.environment}-"
  family      = "postgres${split(".", var.db_engine_version)[0]}"
  description = "Keycloak-optimized PostgreSQL parameters"

  # Log slow queries (queries taking longer than 1 second)
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  # Log DDL statements (schema changes) for audit trail
  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  # Kill idle transactions after 10 minutes to prevent connection leaks
  parameter {
    name  = "idle_in_transaction_session_timeout"
    value = "600000"
  }

  # Apply custom parameters from variable
  dynamic "parameter" {
    for_each = var.db_parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = lookup(parameter.value, "apply_method", "immediate")
    }
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-${var.environment}"
      Environment = var.environment
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

#######################
# Aurora Cluster Parameter Group
# Keycloak-optimized PostgreSQL settings for Aurora
#######################

resource "aws_rds_cluster_parameter_group" "keycloak" {
  count = local.is_any_aurora ? 1 : 0

  name_prefix = "${var.name}-keycloak-${var.environment}-"
  family      = "aurora-postgresql${split(".", var.db_engine_version)[0]}"
  description = "Keycloak-optimized Aurora PostgreSQL cluster parameters"

  # Log slow queries (queries taking longer than 1 second)
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  # Log DDL statements (schema changes) for audit trail
  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  # Kill idle transactions after 10 minutes to prevent connection leaks
  parameter {
    name  = "idle_in_transaction_session_timeout"
    value = "600000"
  }

  # Apply custom parameters from variable
  dynamic "parameter" {
    for_each = var.db_parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = lookup(parameter.value, "apply_method", "immediate")
    }
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-keycloak-${var.environment}"
      Environment = var.environment
    }
  )

  lifecycle {
    create_before_destroy = true
  }
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

# Note: No egress rule needed for database security group.
# AWS security groups are stateful - response traffic to allowed inbound
# connections is automatically permitted. The database never initiates
# outbound connections in this configuration.

#######################
# RDS Instance (Standard PostgreSQL)
#######################

resource "aws_db_instance" "keycloak" {
  count = local.is_rds ? 1 : 0

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
  parameter_group_name   = aws_db_parameter_group.keycloak[0].name

  # tfsec:ignore:aws-rds-specify-backup-retention Backup retention is configurable with validation ensuring minimum 7 days
  backup_retention_period = var.db_backup_retention_period
  backup_window           = var.db_backup_window
  maintenance_window      = var.db_maintenance_window

  deletion_protection       = local.deletion_protection
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${var.name}-keycloak-${var.environment}-final"

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
}

#######################
# Aurora Cluster
#######################

resource "aws_rds_cluster" "keycloak" {
  count = local.is_any_aurora ? 1 : 0

  cluster_identifier = "${var.name}-keycloak-${var.environment}"
  engine             = "aurora-postgresql"
  engine_version     = var.db_engine_version
  database_name      = "keycloak"
  master_username    = "keycloak"
  master_password    = random_password.db_password.result

  db_subnet_group_name            = aws_db_subnet_group.keycloak.name
  vpc_security_group_ids          = [aws_security_group.rds.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.keycloak[0].name

  # Backup configuration
  # tfsec:ignore:aws-rds-specify-backup-retention Backup retention is configurable with validation ensuring minimum 7 days
  backup_retention_period      = var.db_backup_retention_period
  preferred_backup_window      = var.db_backup_window
  preferred_maintenance_window = var.db_maintenance_window

  # Encryption
  storage_encrypted = true
  kms_key_id        = var.db_kms_key_id != "" ? var.db_kms_key_id : null

  # Aurora-specific features
  backtrack_window = local.is_aurora ? local.backtrack_window : 0

  # Serverless v2 scaling configuration
  dynamic "serverlessv2_scaling_configuration" {
    for_each = local.is_aurora_serverless ? [1] : []

    content {
      min_capacity = var.db_capacity_min
      max_capacity = var.db_capacity_max
    }
  }

  # Deletion protection
  deletion_protection       = local.deletion_protection
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${var.name}-keycloak-${var.environment}-final"

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
}

#######################
# Aurora Provisioned Instances
#######################

# Writer instance
resource "aws_rds_cluster_instance" "keycloak_writer" {
  count = local.is_aurora ? 1 : 0

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
  count = local.is_aurora ? local.aurora_replicas : 0

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
# Aurora Serverless v2 Instances
#######################

# Writer instance
resource "aws_rds_cluster_instance" "keycloak_serverless_writer" {
  count = local.is_aurora_serverless ? 1 : 0

  identifier         = "${var.name}-keycloak-${var.environment}-serverless-writer"
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
      Name         = "${var.name}-keycloak-${var.environment}-serverless-writer"
      Environment  = var.environment
      DatabaseType = "aurora-serverless"
      Role         = "writer"
    }
  )
}

# Reader instances (count based on aurora_replica_count, same as Aurora Provisioned)
resource "aws_rds_cluster_instance" "keycloak_serverless_reader" {
  count = local.is_aurora_serverless ? local.aurora_replicas : 0

  identifier         = "${var.name}-keycloak-${var.environment}-serverless-reader-${count.index + 1}"
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
      Name         = "${var.name}-keycloak-${var.environment}-serverless-reader-${count.index + 1}"
      Environment  = var.environment
      DatabaseType = "aurora-serverless"
      Role         = "reader"
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
    host     = local.is_rds ? aws_db_instance.keycloak[0].address : aws_rds_cluster.keycloak[0].endpoint
    port     = local.is_rds ? aws_db_instance.keycloak[0].port : aws_rds_cluster.keycloak[0].port
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
