#!/usr/bin/env bash
# Diagnostic only. No installs, no privileged operations, no daemon access.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
echo '=== REQUIRED: browser Infrastructure Studio ==='
if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys;sys.exit(0 if sys.version_info >= (3,11) else 1)' 2>/dev/null; then
  echo '[OK] Python >=3.11 (stdlib only; requirements.txt has zero packages)'
else
  echo '[BLOCK] Python >=3.11 is missing'
fi
if command -v make >/dev/null 2>&1; then echo '[OK] make'; else echo '[BLOCK] make missing (or use bash scripts/setup-studio.sh directly)'; fi
if command -v git >/dev/null 2>&1; then echo '[OK] Git'; else echo '[INFO] Git required for cloning from GitHub'; fi
if [ -x .venv/bin/python ]; then echo '[OK] .venv exists'; else echo '[INFO] Run make setup to create a project-local .venv'; fi
echo
echo '=== OPTIONAL: real Floci hands-on lab ==='
if bash scripts/terraform.sh version -json >/dev/null 2>&1; then echo '[OK] Terraform 1.17.x selected'; else echo '[INFO] Terraform 1.17.x not available; browser still works'; fi
if command -v aws >/dev/null 2>&1; then echo '[OK] AWS CLI'; else echo '[INFO] AWS CLI needed for local verification/drift'; fi
if command -v curl >/dev/null 2>&1; then echo '[OK] curl'; else echo '[INFO] curl required for Floci API health checks'; fi
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  echo '[OK] Docker Compose CLI exists (daemon permission not tested)'
else
  echo '[INFO] Docker + Compose needed to START Floci or run Docker Studio'
fi
echo
echo '=== OPTIONAL: independent KVM guest ==='
if command -v virsh >/dev/null 2>&1; then echo '[OK] virsh available'; else echo '[INFO] libvirt/KVM unavailable; guest is not required'; fi
echo
echo 'Read-only inventory complete. No packages were installed.'
