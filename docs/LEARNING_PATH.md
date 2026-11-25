# Guided learning: 4 focused labs

Use this order. First inspect a plan, then apply locally, then simulate failure and recover. Each exercise gives you a story for an interview.

## Lab 1 — Terraform execution model (10-15 focused steps)
1. `bash scripts/terraform.sh version` and `make fmt-check`: formatter != validator.
2. `make test`: examine `mock_provider "aws"` in `environments/floci/tests`.
3. `make local-up` then `make local-plan`: identify `+ create` resource types.
4. Explain **provider → module → resource → state → plan** aloud.
5. Change only `project_name` using `-var` in a plan, and observe replacement vs update.

**Question:** why must a .tfstate never be published? Because it contains resource IDs and may contain sensitive values even when outputs are marked sensitive.

## Lab 2 — VPC and routing
1. `make local-apply` then `make local-verify`.
2. Explain `10.42.0.0/16`, `cidrsubnet`, /24 subnets, two availability zones.
3. Show the IGW and route table used by public subnets. Why are private subnets isolated?
4. Observe that public subnet auto-assign public IPv4 is **disabled**.
5. Explain NAT gateway cost and why we deliberately omitted it.

**Question:** does adding an IGW alone make a private EC2 reachable? No. Routing, public IPv4 and SG/NACL policy must allow access; our EC2 has no public IP and no inbound rules.

## Lab 3 — IAM, EC2 and least privilege
1. `make local-ec2-plan` (still a plan, no Docker socket).
2. Inspect metadata `http_tokens=required`, encrypted EBS, empty inbound SG, and VPC-only egress.
3. Compare IAM trust (`sts:AssumeRole` by EC2) vs permission (SSM agent managed policy).
4. Explain why **SSM does NOT magically work** in private isolated subnet without NAT/VPC interface endpoints.
5. Modify a mock test deliberately to expect `http_tokens=optional`; watch it fail, then restore.

**Question:** why is an IAM role preferable to a permanent access key stored on the instance? Short-lived credentials, rotation and better auditability.

## Lab 4 — CI, security and failure drills
1. Push via a PR and inspect all six CI jobs: Terraform/venv, Floci apply-verify-drift-destroy, Docker Studio, libvirt validation, Trivy and Gitleaks.
2. Intentionally change IMDSv2 to optional on a separate practice branch; tests should reject it.
3. Revert, restore green CI, and explain what the security gate protects.
4. Run `make local-plan` twice after an apply; verify zero changes (idempotency).
5. Run `make local-drift` for a guarded out-of-band VPC tag change, strict plan inspection, interactive repair, and proof of restored idempotency. Never perform this against production AWS.
6. On a disposable emulator only, inspect the plan before optionally using `make local-destroy` and `make local-down`. Never delete an existing state to hide drift.

**Interview challenge:** explain why no AWS creds exist in Actions, why `apply` is manual, and why emulation can't prove real production behavior.
