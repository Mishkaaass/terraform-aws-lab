#!/usr/bin/env bash
set -Eeuo pipefail
command -v aws >/dev/null || { echo 'aws CLI required: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html'; exit 1; }
bash scripts/terraform.sh version -json >/dev/null || { echo '[BLOCK] Compatible Terraform required.'; exit 1; }
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VPC_ID="$(bash scripts/terraform.sh -chdir=environments/floci output -raw vpc_id 2>/dev/null || true)"
SG_ID="$(bash scripts/terraform.sh -chdir=environments/floci output -raw security_group_id 2>/dev/null || true)"
if [[ ! "$VPC_ID" =~ ^vpc-[[:alnum:]]+$ ]] || [[ ! "$SG_ID" =~ ^sg-[[:alnum:]]+$ ]]; then
  echo '[BLOCK] Missing or invalid Terraform VPC/SG outputs. Do not verify against an unknown state.' >&2
  echo '[INFO] Check: terraform -chdir=environments/floci workspace show; terraform -chdir=environments/floci state list' >&2
  exit 2
fi
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 AWS_EC2_METADATA_DISABLED=true
unset AWS_PROFILE AWS_SESSION_TOKEN AWS_ROLE_ARN AWS_WEB_IDENTITY_TOKEN_FILE AWS_ENDPOINT_URL || true
printf '=== LOCAL AWS CONTROL PLANE ===\n'
aws --endpoint-url http://127.0.0.1:4566 ec2 describe-vpcs --vpc-ids "$VPC_ID" --query 'Vpcs[0].[VpcId,CidrBlock,State]' --output table
aws --endpoint-url http://127.0.0.1:4566 ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone]' --output table
aws --endpoint-url http://127.0.0.1:4566 ec2 describe-security-groups --group-ids "$SG_ID" --query 'SecurityGroups[0].[GroupId,IpPermissions]' --output json
printf '\n[OK] Queried emulated VPC, subnets, and SG via AWS CLI.\n'
