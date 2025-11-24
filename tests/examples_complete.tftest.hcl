# Test the complete example with VPC, NAT Gateway, and full Keycloak deployment
run "validate_complete" {
  command = apply

  module {
    source = "./examples/complete"
  }
}
