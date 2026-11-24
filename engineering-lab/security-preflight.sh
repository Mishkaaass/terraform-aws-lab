#!/usr/bin/env bash
# Defensive read-only workstation preflight for the Infrastructure Failure Lab.
# Never prints credentials, reads terraform.tfstate, runs sudo, or changes the host.
set -Eeuo pipefail

echo '=== 1. NETWORK LISTENERS (review bind addresses) ==='
if command -v ss >/dev/null 2>&1; then
  ss -lntp | grep -E '(^State|:(8765|18001|18002|4566|8080|8001|8002|5432|18080|18081|5900)[[:space:]])' || true
else
  echo '[UNKNOWN] ss is not available; inspect listening ports manually.'
fi

echo
echo '=== 2. LOCAL FILE-SERVER ACCESS CONTROL ==='
if command -v curl >/dev/null 2>&1; then
  # Loopback only; discard response bodies and prohibit proxies.
  url='http://127.0.0.1:8765'
  code="$(curl --noproxy '*' --max-time 3 -s -o /dev/null -w '%{http_code}' "$url/" || true)"
  if [[ "$code" == "000" || -z "$code" ]]; then
    echo '[NOT RUNNING] Port 8765 not responding. Nothing probed.'
  else
    echo "Local server responds (HTTP $code)."
    unsafe=0
    for path in '/.git/config' '/README.md' '/serve.py' '/terraform.tfstate' '/test_security_server.py'; do
      status="$(curl --noproxy '*' --max-time 3 -s -o /dev/null -w '%{http_code}' "$url$path" || true)"
      if [[ "$status" == 200 ]]; then
        echo "[BLOCK] Sensitive/non-public path readable: $path (HTTP 200)"
        unsafe=1
      else
        echo "[OK] $path not served (HTTP ${status:-unknown})"
      fi
    done
    if [[ "$unsafe" == 1 ]]; then
      echo '[FAIL] Stop the existing 8765 server and use python3 engineering-lab/serve.py'
      exit 1
    fi
  fi
else
  echo '[UNKNOWN] curl is unavailable; static-server access control not tested.'
fi

echo
echo '=== 3. HOST PRIVILEGE EXPOSURE (informational) ==='
if command -v id >/dev/null 2>&1; then
  groups="$(id -nG)"
  case " $groups " in
    *" docker "*) echo '[WARN] Account belongs to the docker group (high-privilege daemon access).' ;;
    *) echo '[OK] Current account is not in the docker group.' ;;
  esac
  case " $groups " in
    *" libvirt "*) echo '[WARN] Account belongs to libvirt group (privileged virtualization access may be possible).' ;;
    *) echo '[INFO] Current account is not in the libvirt group.' ;;
  esac
fi
echo '[INFO] This preflight cannot certify another user, firewall, Docker installation, guest OS or browser.'
