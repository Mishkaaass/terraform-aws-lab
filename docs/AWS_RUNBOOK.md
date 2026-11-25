# Real AWS runbook (opt-in only)

**Do not run this on an employer or production AWS account.** Costs can occur even in labs; deleting a VPC does not replace billing monitoring. The repo defaults `enable_compute=false` and contains no NAT gateway or load balancer.

1. Create/use a separate AWS sandbox account. Enable MFA, IAM Identity Center/SSO, and billing alerts/budgets from the AWS Console. Use a least-privilege deployment role appropriate to these resources; never use the root account.
2. Install the official AWS CLI v2 and Terraform 1.17.2; run `aws configure sso` and `aws sso login --profile YOUR_SANDBOX_PROFILE` as appropriate.
3. Set `AWS_PROFILE=YOUR_SANDBOX_PROFILE` and `AWS_EXPECTED_ACCOUNT_ID=YOUR_12_DIGIT_ID`. Run `aws sts get-caller-identity --profile "$AWS_PROFILE"` and compare IDs. `make aws-plan` also does this.
4. Run `make aws-plan` **only** after confirming the account; inspect resource count and types, region, VPC range, IAM policy, and whether `enable_compute` is false. This reads real AWS and can incur negligible service/API costs depending on account/services.
5. Only if ready to create cloud resources: `I_UNDERSTAND_AWS_CHARGES=YES make aws-apply`. Terraform must still ask for `yes`. Do not pass `-auto-approve`.
6. Review `terraform -chdir=environments/aws output`. Do not expose or upload state.
7. After demo: `I_UNDERSTAND_AWS_CHARGES=YES CONFIRM_AWS_DESTROY=YES make aws-destroy`. Confirm resources are gone in the AWS Console and verify billing.

## Guided command safety

The wrapper refuses inherited Terraform CLI flags, state/workspace overrides,
provider reattachment, custom CLI config and trace logging. Unset the named
variable if a guard blocks your run; do not bypass the guard. Real AWS calls
also reject environment credentials and service-specific endpoint overrides,
ignore profile-configured endpoint URLs, verify a non-root STS identity, and
pass the expected account as an explicit Terraform variable. Apply/destroy
require a real interactive terminal as well as the existing charge/destruction
acknowledgements. The provider independently checks allowed account IDs.
These checks do not make a modified local configuration or a privileged role
safe. Keep the reviewed checkout and Terraform/provider installation trusted.

## IMPORTANT: EC2 is isolated, without SSM connectivity
The private EC2 is intentionally disabled. The private route table has no NAT/default internet route, and no AWS VPC interface endpoints are defined yet. To get secure SSM access, first design the three SSM endpoints (`ssm`, `ssmmessages`, `ec2messages` as required by region), Private DNS, endpoint SG ingress 443 from the VPC, and session permissions. **VPC endpoints have hourly/usage charges**. Do not flip `enable_compute=true` and assume you can connect immediately.

## State strategy
This starter uses local state and ignores it from Git. Before team/shared real-AWS use, bootstrap S3 state with versioning/encryption and modern state locking, scoped IAM and tested recovery; avoid mixing Floci backend and AWS backend. Use separate state keys per environment. Never upload tfstate to a public repository.
