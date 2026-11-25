#!/usr/bin/env bash
# Controlled, local-only Terraform drift detection and repair exercise.
# This script deliberately changes one VPC Name tag in the Floci emulator.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
ENDPOINT="http://127.0.0.1:4566"
EXPECTED_TAG="terraform-aws-lab-vpc"
DRIFT_TAG="terraform-aws-lab-out-of-band"

# Select the project's compatible Terraform version without changing PATH.
bash scripts/terraform.sh version -json >/dev/null
for binary in aws python3; do
  command -v "$binary" >/dev/null 2>&1 || {
    echo "[BLOCK] Missing executable: $binary" >&2
    exit 1
  }
done

# Scope AWS CLI calls to the loopback emulator, with disposable credentials.
# This is a child process: it does not change the user's parent shell.
export NO_PROXY="${NO_PROXY:+$NO_PROXY,}127.0.0.1,localhost"
export no_proxy="${no_proxy:+$no_proxy,}127.0.0.1,localhost"
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_EC2_METADATA_DISABLED=true
unset AWS_PROFILE AWS_ENDPOINT_URL AWS_SESSION_TOKEN AWS_ROLE_ARN AWS_WEB_IDENTITY_TOKEN_FILE || true

AWS=(aws --endpoint-url "$ENDPOINT" --region us-east-1)
TF=(bash scripts/terraform.sh -chdir=environments/floci)

printf '===== 1. LOCAL-ONLY PREFLIGHT =====\n'
bash scripts/wait-floci.sh
VPC_ID="$("${TF[@]}" output -raw vpc_id)"
[[ "$VPC_ID" =~ ^vpc-[a-zA-Z0-9]+$ ]] || {
  echo "[BLOCK] Unexpected VPC ID from Terraform state: $VPC_ID" >&2
  exit 1
}
get_name_tag() {
  "${AWS[@]}" ec2 describe-vpcs --vpc-ids "$VPC_ID" \
    --query "Vpcs[0].Tags[?Key=='Name'].Value | [0]" --output text
}
ACTUAL_TAG="$(get_name_tag)"
[[ "$ACTUAL_TAG" == "$EXPECTED_TAG" ]] || {
  echo "[BLOCK] Unexpected VPC Name tag: $ACTUAL_TAG (expected $EXPECTED_TAG)" >&2
  echo "No mutation performed. Review the existing lab state first." >&2
  exit 1
}

REPORT="$ROOT/reports/drift-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$REPORT"
PLAN="$REPORT/repair.tfplan"
trap 'rm -f -- "$PLAN"' EXIT
printf '[OK] Local Floci VPC %s; tag=%s\n' "$VPC_ID" "$ACTUAL_TAG"

printf '\n===== 2. SIMULATE OUT-OF-BAND CHANGE =====\n'
"${AWS[@]}" ec2 create-tags \
  --resources "$VPC_ID" --tags "Key=Name,Value=$DRIFT_TAG"
ACTUAL_TAG="$(get_name_tag)"
[[ "$ACTUAL_TAG" == "$DRIFT_TAG" ]] || {
  echo "[FAIL] Emulator did not persist the changed tag." >&2
  exit 1
}
printf '[OK] API tag is now %s\n' "$ACTUAL_TAG"

printf '\n===== 3. TERRAFORM DETECTS DRIFT =====\n'
set +e
"${TF[@]}" plan -input=false -no-color -detailed-exitcode \
  -out="$PLAN" > "$REPORT/drift-plan.log" 2>&1
PLAN_EXIT=$?
set -e
if [[ "$PLAN_EXIT" != 2 ]]; then
  echo "[FAIL] Expected Terraform drift exit code 2; got $PLAN_EXIT" >&2
  tail -n 25 "$REPORT/drift-plan.log"
  echo "[NOTE] The local Name tag may still be changed. Review before restoring." >&2
  exit 1
fi

# Hard gate: only the VPC Name tag may change. Any unrelated change blocks repair.
"${TF[@]}" show -json "$PLAN" | python3 -c '
import copy, json, sys
p = json.load(sys.stdin)
changes = [x for x in p.get("resource_changes", []) if x["change"]["actions"] != ["no-op"]]
assert len(changes) == 1, f"Expected exactly 1 change, found {len(changes)}"
c = changes[0]
assert c["address"] == "module.network.aws_vpc.this", c["address"]
assert c["change"]["actions"] == ["update"], c["change"]["actions"]
before = copy.deepcopy(c["change"]["before"])
after = copy.deepcopy(c["change"]["after"])
assert before["tags"]["Name"] == "terraform-aws-lab-out-of-band"
assert after["tags"]["Name"] == "terraform-aws-lab-vpc"
for key in ("tags", "tags_all"):
    if isinstance(before.get(key), dict):
        before[key].pop("Name", None)
    if isinstance(after.get(key), dict):
        after[key].pop("Name", None)
assert before == after, "Unexpected additional attribute change on VPC"
print("[OK] Strict safety gate: only VPC Name tag restoration is planned")
' | tee "$REPORT/plan-guard.txt"

echo '[OK] Drift detected (exit 2) without unexpected changes.'
echo '[INFO] Proof saved locally under reports/ (gitignored).'

printf '\n===== 4. REPAIR (EXPLICIT CONSENT) =====\n'
echo 'Terraform will apply a saved plan that restores ONLY the original VPC Name tag.'
printf "Type 'yes' to repair local drift (anything else leaves the change in Floci): "
read -r APPROVAL
if [[ "$APPROVAL" != yes ]]; then
  echo '[STOP] Repair not approved. Local drift remains.'
  echo 'To recover later: review terraform -chdir=environments/floci plan, then apply.'
  exit 0
fi
"${TF[@]}" apply -input=false "$PLAN" > "$REPORT/repair.log" 2>&1
tail -n 10 "$REPORT/repair.log"

printf '\n===== 5. VERIFY IDEMPOTENCY =====\n'
ACTUAL_TAG="$(get_name_tag)"
[[ "$ACTUAL_TAG" == "$EXPECTED_TAG" ]] || {
  echo "[FAIL] Name tag was not restored: $ACTUAL_TAG" >&2
  exit 1
}
set +e
"${TF[@]}" plan -input=false -no-color -detailed-exitcode \
  > "$REPORT/final-plan.log" 2>&1
FINAL_EXIT=$?
set -e
[[ "$FINAL_EXIT" == 0 ]] || {
  echo "[FAIL] Terraform plan after repair exit=$FINAL_EXIT" >&2
  tail -n 25 "$REPORT/final-plan.log"
  exit 1
}

echo '[PASS] Drift detected, safety-checked, repaired, and verified: No changes.'
printf '[EVIDENCE] %s\n' "$REPORT"
