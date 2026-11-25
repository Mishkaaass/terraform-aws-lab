#!/usr/bin/env bash
# Read-only learning setup diagnostic. No sudo, apply, destroy or Docker changes.
set -u
cd "$(dirname "$0")/.." || exit 1
echo "=== INFRASTRUCTURE STUDIO / READ-ONLY CHECK ==="
echo "1. Terraform for this project"
if vjson="$(bash scripts/terraform.sh version -json 2>/dev/null)"; then
  ver="$(printf '%s' "$vjson" | python3 -c 'import json,sys;print(json.load(sys.stdin)["terraform_version"])' 2>/dev/null || echo unknown)"
  echo "[OK] Project selects Terraform $ver automatically (make test / plan / apply)."
  if command -v terraform >/dev/null 2>&1; then
    shell_ver="$(terraform version -json 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin)["terraform_version"])' 2>/dev/null || echo unknown)"
    if [ "$shell_ver" != "$ver" ]; then
      echo "[INFO] Your terminal defaults to $shell_ver; use make commands or bash scripts/terraform.sh instead."
    fi
  fi
else
  echo "[BLOCK] Compatible Terraform 1.17.x unavailable."
  echo "[INFO] Install the required version in .terraform-version; no automatic install is attempted."
fi
echo
echo "2. Floci availability (optional; not needed for browser or mock tests)"
floci_up=false
if command -v curl >/dev/null 2>&1 && curl --noproxy '*' -fsS --max-time 2 http://127.0.0.1:4566/_floci/health >/dev/null 2>&1; then
  echo "[OK] Local Floci API responds on 127.0.0.1:4566."
  floci_up=true
else
  echo "[INFO] Floci not running. Start it with make local-up only when ready for local lab."
fi
echo
echo "3. Docker access"
if ! command -v docker >/dev/null 2>&1; then
  if [ "$floci_up" = true ]; then
    echo "[INFO] Docker CLI missing, but existing Floci can be used for plans and API inspection."
  else
    echo "[BLOCK] Docker CLI needed to start Floci; browser and make test still work."
  fi
elif command -v timeout >/dev/null 2>&1 && timeout 4 docker info --format '{{.ServerVersion}}' >/dev/null 2>&1; then
  echo "[OK] Docker daemon accessible."
else
  if [ "$floci_up" = true ]; then
    echo "[INFO] Docker permission unavailable, but healthy Floci is reusable. No Docker changes needed."
  else
    echo "[BLOCK] Docker daemon unavailable to current user; cannot start Floci."
  fi
  echo "[INFO] Never chmod 666 docker.sock or add yourself to docker group without understanding root-equivalent access."
fi
echo
echo "4. Terraform state versus running Floci"
if [ -f environments/floci/terraform.tfstate ] && bash scripts/terraform.sh version -json >/dev/null 2>&1; then
  resource_count="$(bash scripts/terraform.sh -chdir=environments/floci state list 2>/dev/null | wc -l || true)"
  vpc="$(bash scripts/terraform.sh -chdir=environments/floci output -raw vpc_id 2>/dev/null || true)"
  if [ -z "$vpc" ] && [ "$resource_count" -eq 0 ]; then
    echo "[INFO] No managed local resources yet. Begin with make local-plan, then review local-apply."
  elif [[ "$vpc" =~ ^vpc-[a-zA-Z0-9]+$ ]] && command -v aws >/dev/null 2>&1 && [ "$floci_up" = true ]; then
    observed="$(env -u AWS_PROFILE -u AWS_SESSION_TOKEN -u AWS_ROLE_ARN -u AWS_WEB_IDENTITY_TOKEN_FILE -u AWS_ENDPOINT_URL AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 AWS_EC2_METADATA_DISABLED=true aws --no-cli-pager --endpoint-url http://127.0.0.1:4566 ec2 describe-vpcs --vpc-ids "$vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || true)"
    if [ "$observed" = "$vpc" ]; then
      echo "[OK] Terraform state VPC $vpc is present in local Floci."
    else
      echo "[BLOCK] Terraform remembers VPC $vpc, but current Floci does not confirm it."
      echo "[INFO] Inspect state and plan before any apply/destroy; do not delete state."
    fi
  elif [ -n "$vpc" ] && [ "$floci_up" != true ]; then
    echo "[INFO] State exists; cannot compare while Floci is offline."
  elif [ -n "$vpc" ]; then
    echo "[INFO] State exists, but AWS CLI missing; run make local-verify after installing AWS CLI."
  else
    echo "[BLOCK] Terraform has $resource_count resources but no VPC output. Inspect before applying."
  fi
else
  echo "[INFO] No local Terraform state. Normal for a new clone."
fi
echo
echo "5. Optional Ubuntu KVM VM (independent of Floci)"
if command -v virsh >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
  state="$(timeout 4 virsh -c qemu:///system domstate tfaws-lab01 2>/dev/null || true)"
  echo "[INFO] VM: ${state:-not found or unavailable}. Not required for this lab."
else
  echo "[INFO] libvirt not installed; optional KVM section may be skipped."
fi
echo
echo "Read-only readiness complete. Resolve BLOCK messages before affected optional stages."
