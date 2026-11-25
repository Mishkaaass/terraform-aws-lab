#!/usr/bin/env bash
# Read-only readiness check for the guided Floci lab. No sudo, apply, destroy,
# container creation, Terraform state modification or changes to PATH.
set -u
cd "$(dirname "$0")/.." || exit 1
echo "=== LOCAL LAB READINESS (NO CHANGES) ==="
echo "1. Terraform version"
if ! command -v terraform >/dev/null 2>&1; then
  echo "[BLOCK] Terraform missing. Project requires 1.17.x."
else
  ver="$(terraform version -json 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin).get("terraform_version","unknown"))' 2>/dev/null || echo unknown)"
  case "$ver" in
    1.17.*) echo "[OK] Terraform $ver" ;;
    *) echo "[BLOCK] Found Terraform $ver; required 1.17.x. Check your PATH." ;;
  esac
fi
pinned="$HOME/.local/opt/terraform/1.17.2/terraform"
if [ -x "$pinned" ]; then
  echo "[INFO] Compatible binary found at ~/.local/opt/terraform/1.17.2/terraform"
  echo "[INFO] In your terminal only: export PATH=\"\$HOME/.local/opt/terraform/1.17.2:\$PATH\""
fi
echo
echo "2. Docker daemon permissions"
if ! command -v docker >/dev/null 2>&1; then
  echo "[BLOCK] Docker CLI missing (needed only for Floci stages)."
elif command -v timeout >/dev/null 2>&1 && timeout 4 docker info --format '{{.ServerVersion}}' >/dev/null 2>&1; then
  echo "[OK] Current user can query Docker daemon."
else
  echo "[BLOCK] Current user cannot query Docker daemon, or daemon not ready."
  echo "[INFO] Do NOT chmod 666 /var/run/docker.sock or blindly add docker group."
  echo "[INFO] Docker group is effectively host-root; use an isolated lab VM or approved setup."
fi
echo
echo "3. Floci local API"
if curl --noproxy '*' -fsS --max-time 2 http://127.0.0.1:4566/_floci/health >/dev/null 2>&1; then
  echo "[OK] Floci health endpoint responds."
else
  echo "[INFO] Floci unavailable on 127.0.0.1:4566. It is optional for mock tests."
fi
echo
echo "4. Terraform local state / emulator alignment"
if [ -f environments/floci/terraform.tfstate ] && command -v terraform >/dev/null 2>&1; then
  tf="$pinned"
  [ -x "$tf" ] || tf="$(command -v terraform)"
  vpc="$("$tf" -chdir=environments/floci output -raw vpc_id 2>/dev/null || true)"
  if [[ "$vpc" =~ ^vpc-[a-zA-Z0-9]+$ ]] && command -v aws >/dev/null 2>&1; then
    # Child-process-only fake credentials; AWS CLI always has localhost endpoint.
    if env -u AWS_PROFILE -u AWS_SESSION_TOKEN -u AWS_ROLE_ARN -u AWS_WEB_IDENTITY_TOKEN_FILE AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 AWS_EC2_METADATA_DISABLED=true aws --no-cli-pager --endpoint-url http://127.0.0.1:4566 ec2 describe-vpcs --vpc-ids "$vpc" --query 'Vpcs[0].VpcId' --output text >/dev/null 2>&1; then
      echo "[OK] State VPC is present in local Floci."
    else
      echo "[BLOCK] State references a VPC that local Floci cannot return."
      echo "[INFO] Stop before verify/drift/apply; do not delete state or run destroy."
    fi
  else
    echo "[INFO] No readable VPC output or AWS CLI; cannot compare with Floci."
  fi
else
  echo "[INFO] No initialized local state or Terraform binary; nothing to compare."
fi
echo
echo "5. VM (separate from the Floci emulator)"
if command -v virsh >/dev/null 2>&1; then
  state="$(timeout 4 virsh -c qemu:///system domstate tfaws-lab01 2>/dev/null || true)"
  echo "[INFO] KVM VM: ${state:-not accessible}. Not required for Floci."
else
  echo "[INFO] libvirt unavailable. Optional KVM stage can be skipped."
fi
echo
echo "Read-only check completed. Treat any BLOCK as a stop before further real-lab actions."
