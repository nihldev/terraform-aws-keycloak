# Keycloak-specific validation policies for OPA/Conftest
package main

import rego.v1

# METADATA
# title: Keycloak Multi-Instance Cache Configuration
# description: Ensures distributed cache is enabled when running multiple Keycloak instances
# custom:
#   severity: HIGH
deny contains msg if {
	some resource in input.resource.aws_ecs_service
	resource.desired_count > 1
	not has_distributed_cache
	msg := sprintf(
		"ECS service '%s' has desired_count > 1 but distributed cache may not be configured. Ensure KC_CACHE=ispn and KC_CACHE_STACK=jdbc-ping are set.",
		[resource.__key__],
	)
}

# Check if distributed cache is configured in the task definition environment variables
has_distributed_cache if {
	some local in input.locals
	some env in local.cache_environment
	env.name == "KC_CACHE"
	env.value == "ispn"
}

# METADATA
# title: Keycloak Hostname Strict Backchannel
# description: Ensures KC_HOSTNAME_STRICT_BACKCHANNEL is set when KC_HOSTNAME_STRICT is enabled
# custom:
#   severity: HIGH
deny contains msg if {
	some local in input.locals
	some env in local.hostname_environment
	env.name == "KC_HOSTNAME_STRICT"
	env.value == "true"
	not has_backchannel_config
	msg := "KC_HOSTNAME_STRICT is enabled but KC_HOSTNAME_STRICT_BACKCHANNEL is not configured. Health checks may fail."
}

has_backchannel_config if {
	some local in input.locals
	some env in local.hostname_environment
	env.name == "KC_HOSTNAME_STRICT_BACKCHANNEL"
}

# METADATA
# title: ECS Deployment Circuit Breaker
# description: Ensures ECS services have deployment circuit breaker enabled for automatic rollback
# custom:
#   severity: MEDIUM
warn contains msg if {
	some resource in input.resource.aws_ecs_service
	not resource.deployment_circuit_breaker
	msg := sprintf(
		"ECS service '%s' should enable deployment_circuit_breaker for automatic rollback on failed deployments",
		[resource.__key__],
	)
}

# METADATA
# title: ALB Access Logging
# description: Recommends enabling ALB access logs for audit and troubleshooting
# custom:
#   severity: MEDIUM
warn contains msg if {
	some resource in input.resource.aws_lb
	not resource.access_logs
	msg := sprintf(
		"ALB '%s' should enable access_logs for security audit trails and troubleshooting",
		[resource.__key__],
	)
}

# METADATA
# title: RDS Customer-Managed KMS Key
# description: Recommends using customer-managed KMS keys for RDS encryption
# custom:
#   severity: MEDIUM
warn contains msg if {
	some resource in input.resource.aws_db_instance
	resource.storage_encrypted == true
	not resource.kms_key_id
	msg := sprintf(
		"RDS instance '%s' uses AWS-managed encryption key. Consider using customer-managed KMS key for better control",
		[resource.__key__],
	)
}

# METADATA
# title: Secrets Manager Customer-Managed KMS Key
# description: Recommends using customer-managed KMS keys for Secrets Manager
# custom:
#   severity: MEDIUM
warn contains msg if {
	some resource in input.resource.aws_secretsmanager_secret
	not resource.kms_key_id
	msg := sprintf(
		"Secrets Manager secret '%s' uses AWS-managed encryption key. Consider using customer-managed KMS key for better control",
		[resource.__key__],
	)
}

# METADATA
# title: Database Connection Pool Configuration
# description: Ensures database connection pool is configured for Keycloak
# custom:
#   severity: LOW
warn contains msg if {
	some local in input.locals
	not has_db_pool_config(local.base_environment)
	msg := "Database connection pool settings (KC_DB_POOL_*) should be configured for optimal performance"
}

has_db_pool_config(env_list) if {
	some env in env_list
	env.name == "KC_DB_POOL_MAX_SIZE"
}
