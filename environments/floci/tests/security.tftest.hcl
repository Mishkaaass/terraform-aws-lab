mock_provider "aws" {}

run "secure_compute_opt_in" {
  command = plan
  variables {
    enable_compute = true
  }
  assert {
    condition     = module.compute.instance_count == 1
    error_message = "Opted-in EC2 must be represented in the plan."
  }
  assert {
    condition     = module.compute.imdsv2_required
    error_message = "IMDSv2 must be enforced."
  }
  assert {
    condition     = module.compute.root_disk_encrypted
    error_message = "EC2 root volume must be encrypted."
  }
  assert {
    condition     = !module.compute.has_public_ipv4
    error_message = "EC2 must not have a public IPv4 address."
  }
  assert {
    condition     = module.identity.managed_policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "EC2 must only receive the intended SSM managed policy."
  }
  assert {
    condition     = module.security.egress_cidr == "10.42.0.0/16"
    error_message = "Egress is VPC-only; public internet egress is not allowed."
  }
  assert {
    condition     = module.security.egress_port == 443
    error_message = "Outbound traffic must be restricted to HTTPS in this lab."
  }
}
