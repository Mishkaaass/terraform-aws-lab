#!/usr/bin/env bash
# Smoke only a newly created container; no mounts, public ports or network.
set -Eeuo pipefail
[[ $# -eq 1 && -n "$1" ]] || { echo 'Usage: smoke-studio-image.sh IMAGE' >&2; exit 2; }
cid="$(docker create --network none --read-only --user 65532:65532 \
  --cap-drop ALL --security-opt no-new-privileges --pids-limit 64 \
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=32m "$1")"
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
docker start "$cid" >/dev/null
docker exec -i "$cid" python3 -B - <<'PY'
import http.client
import os
import time

assert os.getuid() == 65532

def request(path, *, method="GET", headers=None):
    connection = http.client.HTTPConnection("127.0.0.1", 8765, timeout=3)
    try:
        connection.request(method, path, headers=headers or {})
        response = connection.getresponse()
        return response.status, dict(response.getheaders()), response.read()
    finally:
        connection.close()

for attempt in range(25):
    try:
        status, headers, body = request("/")
        if status == 200:
            break
    except OSError:
        pass
    time.sleep(1)
else:
    raise RuntimeError("Fresh Studio did not become ready")

assert b"Infrastructure Studio" in body
assert headers["X-Frame-Options"] == "DENY"
assert "frame-ancestors 'none'" in headers["Content-Security-Policy"]
assert headers["X-Content-Type-Options"] == "nosniff"
for asset in ("/index.html", "/app.js", "/style.css", "/missions.json"):
    assert request(asset)[0] == 200
for denied in ("/.git/config", "/terraform.tfstate", "/.terraform/", "/serve.py",
               "/../etc/passwd", "/index.html?secret=1"):
    assert request(denied)[0] == 404
assert request("/", headers={"Host": "untrusted.invalid"})[0] == 400
assert request("/", headers={"Origin": "https://untrusted.invalid"})[0] == 403
assert request("/", method="POST")[0] == 501
print("[PASS] Isolated non-root Studio image: assets, headers, deny paths and read-only HTTP")
PY
