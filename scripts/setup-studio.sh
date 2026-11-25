#!/usr/bin/env bash
# Local, reproducible Python setup. No sudo, no pip downloads, no global installs.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if ! command -v python3 >/dev/null 2>&1; then
  echo '[BLOCK] Python 3.11+ is required (install python3 and python3-venv).' >&2
  exit 2
fi
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3,11) else 1)' || {
  echo '[BLOCK] Python 3.11+ is required.' >&2
  exit 2
}
if [[ ! -x .venv/bin/python ]]; then
  echo '[SETUP] Creating .venv (stdlib only, no package downloads).'
  python3 -m venv .venv || {
    echo '[BLOCK] Could not create .venv; on Debian/Ubuntu install python3-venv.' >&2
    exit 2
  }
else
  echo '[REUSE] Existing project .venv.'
fi
.venv/bin/python -c 'import sys,venv; assert sys.prefix != sys.base_prefix; assert sys.version_info >= (3,11)' || {
  echo '[BLOCK] Existing .venv is invalid/incompatible. Inspect it; setup will not delete it.' >&2
  exit 2
}
echo '[PASS] Studio environment ready at .venv/bin/python (0 third-party requirements).'
