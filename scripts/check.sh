#!/usr/bin/env bash
set -Eeuo pipefail
printf '=== TOOLCHAIN ===\n'
for cmd in terraform docker aws git python3; do
  if command -v "$cmd" >/dev/null 2>&1; then
    case "$cmd" in
      terraform) printf '[OK] terraform: '; terraform version | head -n 1 ;;
      docker) printf '[OK] docker: '; docker --version ;;
      *) printf '[OK] %s\n' "$cmd" ;;
    esac
  else
    printf '[MISSING] %s\n' "$cmd"
  fi
done
printf '\n=== SAFETY ===\n'
if grep -R -E -n '^[[:space:]]*(access_key|secret_key)[[:space:]]*=' environments/aws/ --include='*.tf' 2>/dev/null; then
  echo 'FAIL: static credentials detected in real AWS root.'; exit 1
fi
printf '[OK] AWS root has no static provider access/secret keys.\n'
if grep -R -E -n '/var/run/docker.sock' compose.yaml | grep -v '^[^:]*:[[:digit:]]*:[[:space:]]*#' >/dev/null; then
  echo 'FAIL: default Compose must not mount Docker socket.'; exit 1
fi
printf '[OK] Floci default Compose has no Docker socket mount.\n'
if grep -q 'cidr_ipv4[[:space:]]*=[[:space:]]*"0.0.0.0/0"' modules/security/main.tf; then
  echo 'FAIL: public internet egress is forbidden.'; exit 1
fi
printf '[OK] No public egress rule in instance SG.\n'

# The security module must have no ingress resource or inline ingress block.
if grep -E -q 'resource[[:space:]]+"aws_vpc_security_group_ingress_rule"|^[[:space:]]*ingress[[:space:]]*\{' modules/security/main.tf; then
  echo 'FAIL: unexpected inbound security-group policy.'; exit 1
fi
echo '[OK] No inbound rule declared in security module.'
