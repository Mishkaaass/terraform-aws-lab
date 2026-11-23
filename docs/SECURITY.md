# Security model and threat boundaries

| Control | What it protects | What it does not prove |
| --- | --- | --- |
| AWS `allowed_account_ids` | Wrong-account provisioning via real AWS provider | Credentials' IAM least privilege or cost ceiling |
| Real AWS command guard | Profile & identity verification; explicit change/destroy consent | Manual direct Terraform commands outside helper scripts |
| Separate roots + local endpoints | Local Floci cannot accidentally target real AWS for used services | Other scripts run by a user outside this project |
| No Docker socket | Prevents exposing privileged host Docker daemon to Floci | Safety of all container images or tools |
| Zero SG ingress | No instance inbound services | Other VPC/network policy layers |
| VPC-only HTTPS SG egress | Limits outbound to VPC CIDR on port 443 | Cannot reach internet or SSM until private endpoints exist |
| Private EC2, IMDSv2, encrypted gp3 | EC2 network exposure, metadata access, disk-at-rest | OS patching, key lifecycle, full production security |
| IAM SSM agent policy | Avoids AdminAccess | Interface endpoints needed for isolated subnet management |
| CI read-only permissions | No automatic deployments with GITHUB_TOKEN | GitHub organization policy and runner supply-chain risks |
| Terraform mock tests | Terraform configuration invariants | AWS actual behavior, drift, pricing |
| Trivy IaC scan | Known configuration risks | All vulnerabilities and business logic errors |

## Before public release
- Inspect CI failures and handle real Trivy findings rather than suppressing all.
- Commit `.terraform.lock.hcl` for **both** roots after `terraform init`.
- Replace remaining release-tagged third-party CI actions with full-length, independently verified commit SHAs.
- Enable GitHub branch protection / required checks / dependency updates / secret scanning.
- Keep `terraform.tfstate`, `terraform.tfvars`, `.aws/`, and passwords out of Git.
- Never use root AWS access keys; prefer AWS IAM Identity Center/SSO + a dedicated limited sandbox role.
- Floci is an emulator; **do not** describe its network isolation as production AWS behavior.
