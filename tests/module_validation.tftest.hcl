# Test module resource creation and configuration
run "validate_module_resources" {
  command = plan

  variables {
    name        = "test-keycloak"
    environment = "test"
  }

  module {
    source = "./examples/basic"
  }

  # Verify plan creates expected resources
  # Note: Actual resource counts depend on the module implementation
  assert {
    condition     = length([for r in terraform_plan.resource_changes : r if r.change.actions[0] == "create"]) > 0
    error_message = "Plan should create resources"
  }
}
