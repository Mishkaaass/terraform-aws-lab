#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ACTION="${1:-}"
case "$ACTION" in plan|apply|destroy) ;; *) echo 'Usage: scripts/aws-command.sh plan|apply|destroy' >&2; exit 2 ;; esac
for cmd in aws bash; do
  command -v "$cmd" >/dev/null || { echo "$cmd required." >&2; exit 1; }
done
for forbidden in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_WEB_IDENTITY_TOKEN_FILE; do
  if [[ -n "${!forbidden:-}" ]]; then
    echo "[BLOCK] $forbidden is set; unset it and use an explicit SSO/profile login." >&2
    exit 1
  fi
done
[[ -n "${AWS_PROFILE:-}" ]] || { echo '[BLOCK] Set AWS_PROFILE to a non-default sandbox profile.' >&2; exit 1; }
[[ "${AWS_PROFILE}" != "default" ]] || { echo '[BLOCK] The default AWS profile is forbidden.' >&2; exit 1; }
[[ "${AWS_EXPECTED_ACCOUNT_ID:-}" =~ ^[0-9]{12}$ ]] || { echo '[BLOCK] Set AWS_EXPECTED_ACCOUNT_ID to your 12-digit sandbox account.' >&2; exit 1; }
[[ -z "${AWS_ENDPOINT_URL:-}" ]] || { echo '[BLOCK] Unset AWS_ENDPOINT_URL for the real AWS root.' >&2; exit 1; }
export AWS_EC2_METADATA_DISABLED=true
REAL_ID="$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)"
if [[ "$REAL_ID" != "$AWS_EXPECTED_ACCOUNT_ID" ]]; then
  echo "[BLOCK] Wrong AWS account: got $REAL_ID, expected $AWS_EXPECTED_ACCOUNT_ID" >&2; exit 1
fi
printf '[OK] AWS account verified: %s, profile=%s\n' "$REAL_ID" "$AWS_PROFILE"
if [[ "$ACTION" != plan ]]; then
  [[ "${I_UNDERSTAND_AWS_CHARGES:-}" == YES ]] || { echo '[BLOCK] Set I_UNDERSTAND_AWS_CHARGES=YES for real changes.' >&2; exit 1; }
fi
if [[ "$ACTION" == destroy ]]; then
  [[ "${CONFIRM_AWS_DESTROY:-}" == YES ]] || { echo '[BLOCK] Set CONFIRM_AWS_DESTROY=YES to allow interactive destroy.' >&2; exit 1; }
fi
export TF_VAR_expected_account_id="$AWS_EXPECTED_ACCOUNT_ID"
bash "$ROOT/scripts/terraform.sh" -chdir="$ROOT/environments/aws" init -input=false
# Do NOT use -auto-approve. Terraform will show the plan and ask for confirmation.
bash "$ROOT/scripts/terraform.sh" -chdir="$ROOT/environments/aws" "$ACTION"
