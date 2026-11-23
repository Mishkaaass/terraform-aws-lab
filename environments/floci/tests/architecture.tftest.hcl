# No AWS account and no Floci container are needed for this test.
mock_provider "aws" {}

run "two_zone_network_topology" {
  command = plan
  assert {
    condition     = length(module.network.public_subnet_ids) == 2 && length(module.network.private_subnet_ids) == 2
    error_message = "Expected two public and two private subnets."
  }
  assert {
    condition     = module.network.public_subnet_cidrs[0] != module.network.private_subnet_cidrs[0]
    error_message = "Public/private address ranges must be distinct."
  }
  assert {
    condition     = module.network.public_default_route_destination == "0.0.0.0/0"
    error_message = "Public subnets require IGW default route."
  }
  assert {
    condition     = module.compute.instance_count == 0
    error_message = "Compute must be off by default in a safe lab."
  }
}
