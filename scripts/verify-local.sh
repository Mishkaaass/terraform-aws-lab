#!/usr/bin/env bash
set -Eeuo pipefail
command -v aws >/dev/null || { echo 'aws CLI required: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html'; exit 1; }
command -v terraform >/dev/null || { echo 'Terraform required.'; exit 1; }
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VPC_ID="$(terraform -chdir=environments/floci output -raw vpc_id)"
SG_ID="$(terraform -chdir=environments/floci output -raw security_group_id)"
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 AWS_EC2_METADATA_DISABLED=true
unset AWS_PROFILE || true
printf '=== LOCAL AWS CONTROL PLANE ===\n'
aws --endpoint-url http://127.0.0.1:4566 ec2 describe-vpcs --vpc-ids "$VPC_ID" --query 'Vpcs[0].[VpcId,CidrBlock,State]' --output table
aws --endpoint-url http://127.0.0.1:4566 ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone]' --output table
aws --endpoint-url http://127.0.0.1:4566 ec2 describe-security-groups --group-ids "$SG_ID" --query 'SecurityGroups[0].[GroupId,IpPermissions]' --output json
printf '\n[OK] Queried emulated VPC, subnets, and SG via AWS CLI.\n'
