# Changelog

## [1.0.0] — 2026-11-25

**First reproducible, safe reviewer release of Terraform AWS Lab.**

### Learn it in a browser
- Source-grounded architecture map for a VPC, two public and two isolated private subnets, routing, IAM and security groups.
- Non-executing design what-if sandbox, guided CLI checkpoints and seven engineering incident cases.
- Optional read-only Floci/KVM observations; stopped KVM guest is an expected, non-failing status.

### Run it safely
- `make requirements` and `make setup` create a local `.venv` using **only Python standard library**.
- `make studio` runs under `.venv/bin/python`, without a global pip install.
- `make studio-docker` builds the same browser assets in an isolated non-root, read-only image, based on a pinned official Python OCI index.
- The Docker build context excludes Git, Terraform, state, credentials and all non-public files; the host port binds to loopback only.
- Terraform 1.17.x selection is isolated from a user's older global Terraform version.

### Test and recover
- Floci is pinned to a multi-architecture 2.5.0 OCI digest.
- `make local-verify` now fails if live emulator VPC/subnets, routes, IGW, security-group rules, IAM policy or disabled compute violate declared invariants.
- Negative unit tests prove that opening SSH, adding public egress, breaking route isolation or attaching IAM AdministratorAccess are rejected.
- GitHub CI independently builds/verifies the Studio container, tests the venv path, and applies/verifies/drifts/repairs/destroys Floci resources in an ephemeral runner.
- PR security gates cover Terraform, the VM's static configuration, Trivy and Gitleaks.

### Deliberate limitations
- This is an **educational AWS API emulation**, not real AWS dataplane or IAM enforcement.
- No real AWS account is needed and EC2 remains off by default.
- Running KVM, real AWS deployment, SSM interface endpoints, remote Terraform backend and cloud spending are out of scope.
- Docker daemon access is privileged; a browser-only reviewer should use the local Python venv route if Docker is unavailable.

**Full setup:** [README](README.md) and [Run Requirements](docs/REQUIREMENTS.md). **Review demo:** [Interview guide](docs/INTERVIEW.md).
