#!/usr/bin/env bash
# Select the version required by this repository without changing the user's PATH.
# Safe to invoke through: bash scripts/terraform.sh <terraform arguments>
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/terraform-environment.sh"
lab_check_terraform_environment
# Local AWS API requests must bypass any inherited HTTP proxy.
case "${1:-}" in
  -chdir=environments/floci|-chdir=*/environments/floci)
    export NO_PROXY="${NO_PROXY:+$NO_PROXY,}127.0.0.1,localhost"
    export no_proxy="${no_proxy:+$no_proxy,}127.0.0.1,localhost"
    ;;
esac
required="$(tr -d '[:space:]' < "$ROOT/.terraform-version")"
if [[ ! "$required" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "[BLOCK] Invalid .terraform-version in repository." >&2
  exit 2
fi
pinned="$HOME/.local/opt/terraform/$required/terraform"
if [[ -x "$pinned" ]]; then
  binary="$pinned"
elif command -v terraform >/dev/null 2>&1; then
  binary="$(command -v terraform)"
else
  echo "[BLOCK] Terraform $required not installed." >&2
  echo "[INFO] Install the version in .terraform-version or via a trusted version manager." >&2
  exit 2
fi
version_json="$("$binary" version -json 2>/dev/null)" || {
  echo "[BLOCK] Unable to run selected Terraform binary." >&2
  exit 2
}
pattern='"terraform_version"[[:space:]]*:[[:space:]]*"([0-9]+\.[0-9]+\.[0-9]+)"'
if [[ "$version_json" =~ $pattern ]]; then
  found="${BASH_REMATCH[1]}"
else
  echo "[BLOCK] Unable to determine selected Terraform version." >&2
  exit 2
fi
if [[ "${found%.*}" != "${required%.*}" ]]; then
  echo "[BLOCK] Found Terraform $found; this repository requires $required (1.17.x)." >&2
  echo "[INFO] The project does not change PATH or automatically download binaries." >&2
  exit 2
fi
exec "$binary" "$@"
