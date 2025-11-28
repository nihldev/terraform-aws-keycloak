# Test the basic example with minimal configuration
run "validate_basic" {
  command = apply

  module {
    source = "./examples/basic"
  }
}
