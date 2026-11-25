#!/usr/bin/env python3
"""Read-only, minimized localhost observations for the Infrastructure Studio.

No environment variable secrets, no AWS credentials, no shell, no Terraform,
no sudo and no remote network. Exits safely when libvirt or Floci is absent.
"""
from __future__ import annotations

import ipaddress
import json
import re
import subprocess
import urllib.error
import urllib.request
from datetime import datetime, timezone
from typing import Any

ALLOWED_STATES = {"running", "shut off", "paused", "in shutdown", "crashed", "pmsuspended"}
VM_NAME = "tfaws-lab01"
TIMEOUT = 3


def run_fixed(argv: list[str]) -> str | None:
    try:
        # Never inherit a shell command; stderr/stdout are discarded on failure.
        result = subprocess.run(
            argv, capture_output=True, text=True, timeout=TIMEOUT,
            check=False, stdin=subprocess.DEVNULL,
        )
        return result.stdout[:8192] if result.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def floci() -> str:
    try:
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        req = urllib.request.Request(
            "http://127.0.0.1:4566/_floci/health",
            headers={"Accept": "application/json"}, method="GET",
        )
        with opener.open(req, timeout=TIMEOUT) as response:
            # A small 2xx response proves local reachability, not resource readiness.
            return "up" if 200 <= response.status < 300 else "down"
    except (OSError, urllib.error.URLError, TimeoutError, ValueError):
        return "down"


def vm_state() -> str:
    raw = run_fixed(["virsh", "-c", "qemu:///system", "domstate", VM_NAME])
    if raw is None:
        return "unknown"
    state = raw.strip().lower()
    if state not in ALLOWED_STATES:
        return "unknown"
    return "running" if state == "running" else "stopped"


def ip_from_lease() -> str:
    text = run_fixed(["virsh", "-c", "qemu:///system", "net-dhcp-leases", "default"])
    if text is None:
        return ""
    # Read only the expected IPv4 subnet; a lease is not cryptographic VM identity.
    matches = re.findall(r"\b(192\.168\.122\.\d{1,3})/\d{1,2}\b", text)
    valid = []
    for value in matches:
        try:
            ip = ipaddress.ip_address(value)
            if ip in ipaddress.ip_network("192.168.122.0/24"):
                valid.append(value)
        except ValueError:
            pass
    # Do not guess which guest owns a lease when more than one exists.
    return valid[0] if len(valid) == 1 else ""


def guest_health(ip: str) -> str:
    if not ip:
        return "unknown"
    try:
        # Recheck the fixed net to prevent misuse of this helper as a URL fetcher.
        if ipaddress.ip_address(ip) not in ipaddress.ip_network("192.168.122.0/24"):
            return "unknown"
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        req = urllib.request.Request(f"http://{ip}:8080/health", method="GET")
        with opener.open(req, timeout=TIMEOUT) as response:
            if response.status != 200:
                return "unavailable"
            data = response.read(512)
        doc: Any = json.loads(data)
        return "healthy" if isinstance(doc, dict) and doc.get("status") == "ok" and doc.get("service") == "terraform-libvirt-lab" else "unavailable"
    except (OSError, ValueError, TimeoutError, urllib.error.URLError):
        return "unavailable"


def collect() -> dict:
    vm = vm_state()
    ip = ip_from_lease() if vm == "running" else ""
    return {
        "schema": 1,
        "source": "local-readonly-probe",
        "observed_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "floci": floci(),
        "vm": vm,
        "health": guest_health(ip) if vm == "running" else "unknown",
        "vm_ip": ip,
    }


if __name__ == "__main__":
    print(json.dumps(collect(), sort_keys=True))
