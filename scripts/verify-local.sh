#!/usr/bin/env bash
# Compatibility entrypoint. All validation is in the unit-tested, read-only
# Python checker. Do not use JMESPath tables alone as a pass/fail signal.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
exec python3 scripts/verify_local.py
