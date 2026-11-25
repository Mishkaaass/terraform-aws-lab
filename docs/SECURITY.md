# Security model — local training and guarded real-AWS separation

This is an educational IaC and local AWS API lab, **not** a production-certified network or a cloud penetration test.

| Guard | What the code and tests check | What remains unproven |
| --- | --- | --- |
| Separate Terraform roots | Floci provider has explicit localhost EC2/IAM/STS endpoints and fake credentials; AWS root has `allowed_account_ids` | Manual commands outside these workflows |
| Guarded real-AWS scripts | Explicit non-default profile, expected account ID and interactive consent for apply/destroy | Cloud service costs, IAM least privilege and production readiness |
| Default instance network | No SG ingress, VPC-only TCP 443 egress, private EC2 (disabled), IMDSv2 and encrypted EBS | Real AWS dataplane, OS security, runtime SSM reachability |
| Local integration verifier | Verifies actual Floci VPC, 2-AZ subnet placement, route associations, IGW, SG, IAM attached policy | Actual AWS implementation of IAM/routing; availability |
| No privileged Docker socket | Compose does not mount host Docker daemon; emulator only binds loopback | Complete safety of the Docker daemon or third-party images |
| Pinned supply chain | Terraform provider lockfiles, SHA-pinned Actions and Floci `2.5.0` OCI image index digest | Absence of image vulnerabilities or image-signature verification |
| Browser Studio / venv / Docker | Host venv server binds loopback; optional Docker UI binds within the container but maps only 127.0.0.1 on the host, copies five allowlisted assets, runs read-only/non-root without socket mount; CSP and Host/Origin checks | Browser-OS compromise, Docker daemon privileges, or modified local Compose config |
| CI checks | Terraform configuration tests, real emulated API apply/verify/drift/destroy, Trivy and Gitleaks | Formal security assurance or real-world cloud behavior |

## Local threat boundary

The browser never invokes Terraform, Docker, `sudo`, AWS or libvirt. The recommended `make setup` creates only a project-local Python `.venv` and installs no PyPI packages. The Docker Studio route is optional and has a deny-by-default build context (no repository state, credentials or Git metadata). The reviewer runs CLI commands manually. The UI's pasted-output matching is **not cryptographic attestation**. Fixed-schema `probe.py` JSON with `vm: stopped` is a valid observation, not evidence that the Ubuntu guest is healthy.

The Floci image is pinned in `compose.yaml` to an immutable multi-platform release index from Docker Hub; version changes require a deliberate PR and green CI. Existing healthy local Floci containers are reused by `make local-up`: this avoids disrupting a user's emulator state, but the running container may predate the current Compose image. Never recreate a running emulator automatically to “make the version match.”

The isolated private subnets have **no default route, NAT or SSM endpoints**. The SSM IAM agent policy gives permission but not network reachability. EC2 is **off by default**; executing EC2 in Floci would require additional privileged configuration deliberately not included.

## Release and ongoing maintenance

- Commit provider lockfiles for both Terraform AWS roots and review Dependabot changes in PRs.
- Require CI checks and human review before merging when repository policy permits; branch protection settings are managed in GitHub and cannot be inferred from CI output.
- Keep Terraform state, `*.tfvars`, secrets, personal accounts and AWS credentials out of Git.
- No root AWS access keys. Use SSO, a dedicated AWS sandbox, budget alerts and manual account verification if choosing to explore real AWS; see [AWS_RUNBOOK.md](AWS_RUNBOOK.md).
- Security limitations from the historical [November 24 audit](SECURITY_AUDIT_2026-11-24.md) remain tracked; that review also includes a **different** CI/CD project, which is intentionally not modified here.
- An all-green pipeline means the **specified checks passed**, not that the system is immune to attacks.
