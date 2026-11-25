#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/terraform-environment.sh"
lab_check_terraform_environment
ACTION="${1:-}"
case "$ACTION" in plan|apply|destroy) ;; *) echo 'Usage: scripts/aws-command.sh plan|apply|destroy' >&2; exit 2 ;; esac
for cmd in aws bash; do
  command -v "$cmd" >/dev/null || { echo "$cmd required." >&2; exit 1; }
done
for forbidden in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN AWS_WEB_IDENTITY_TOKEN_FILE AWS_ROLE_ARN AWS_CONTAINER_CREDENTIALS_FULL_URI AWS_CONTAINER_CREDENTIALS_RELATIVE_URI AWS_CONTAINER_AUTHORIZATION_TOKEN AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE ${!AWS_ENDPOINT_URL@}; do
  if [[ -n "${!forbidden:-}" ]]; then
    echo "[BLOCK] $forbidden is set; unset it and use an explicit SSO/profile login without endpoint overrides." >&2
    exit 1
  fi
done
[[ -n "${AWS_PROFILE:-}" ]] || { echo '[BLOCK] Set AWS_PROFILE to a non-default sandbox profile.' >&2; exit 1; }
[[ "${AWS_PROFILE}" != "default" ]] || { echo '[BLOCK] The default AWS profile is forbidden.' >&2; exit 1; }
[[ "${AWS_EXPECTED_ACCOUNT_ID:-}" =~ ^[0-9]{12}$ ]] || { echo '[BLOCK] Set AWS_EXPECTED_ACCOUNT_ID to your 12-digit sandbox account.' >&2; exit 1; }
[[ -z "${AWS_DEFAULT_PROFILE:-}" || "$AWS_DEFAULT_PROFILE" == "$AWS_PROFILE" ]] || { echo '[BLOCK] Conflicting AWS_DEFAULT_PROFILE.' >&2; exit 1; }
if [[ "$ACTION" != plan ]]; then
  [[ "${I_UNDERSTAND_AWS_CHARGES:-}" == YES ]] || { echo '[BLOCK] Set I_UNDERSTAND_AWS_CHARGES=YES for real changes.' >&2; exit 1; }
fi
if [[ "$ACTION" == destroy ]]; then
  [[ "${CONFIRM_AWS_DESTROY:-}" == YES ]] || { echo '[BLOCK] Set CONFIRM_AWS_DESTROY=YES to allow interactive destroy.' >&2; exit 1; }
fi
if [[ "$ACTION" != plan && ( ! -t 0 || ! -t 1 ) ]]; then
  echo '[BLOCK] Real AWS apply/destroy requires an interactive terminal.' >&2
  exit 1
fi
export AWS_EC2_METADATA_DISABLED=true
export AWS_IGNORE_CONFIGURED_ENDPOINT_URLS=true
export AWS_PAGER=""
export AWS_CLI_AUTO_PROMPT=off
identity="$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query '[Account,Arn]' --output text)"
read -r REAL_ID CALLER_ARN EXTRA <<< "$identity"
if [[ "$REAL_ID" != "$AWS_EXPECTED_ACCOUNT_ID" || -n "$EXTRA" ]]; then
  echo '[BLOCK] STS did not return the expected sandbox account.' >&2
  exit 1
fi
case "$CALLER_ARN" in
  arn:*:iam::"$REAL_ID":user/*|arn:*:sts::"$REAL_ID":assumed-role/*|arn:*:sts::"$REAL_ID":federated-user/*) ;;
  *) echo '[BLOCK] Root or unsupported AWS identity. Use a sandbox role.' >&2; exit 1 ;;
esac
echo '[OK] AWS sandbox account and non-root identity verified.'
bash "$ROOT/scripts/terraform.sh" -chdir="$ROOT/environments/aws" init -input=false -lockfile=readonly
# Command-line account selection outranks TF_VAR and auto-loaded tfvars.
# Do NOT use -auto-approve. Terraform must show the plan and ask for consent.
bash "$ROOT/scripts/terraform.sh" -chdir="$ROOT/environments/aws" "$ACTION" -input=true "-var=expected_account_id=$AWS_EXPECTED_ACCOUNT_ID"
