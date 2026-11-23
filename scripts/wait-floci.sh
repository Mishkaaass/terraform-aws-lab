#!/usr/bin/env bash
set -Eeuo pipefail
command -v curl >/dev/null || { echo 'curl required.'; exit 1; }
for attempt in $(seq 1 30); do
  if curl -fsS --max-time 2 http://127.0.0.1:4566/_floci/health >/dev/null 2>&1; then
    echo '[OK] Floci API responding on 127.0.0.1:4566'
    exit 0
  fi
  sleep 1
done
echo '[ERROR] Floci not responding. Inspect: docker compose logs floci' >&2
exit 1
