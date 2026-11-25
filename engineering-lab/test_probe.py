#!/usr/bin/env python3
"""Local-probe unit tests: mock external observations, never start services."""
from __future__ import annotations

import importlib.util
import pathlib
import unittest
from unittest.mock import patch

FILE = pathlib.Path(__file__).with_name("probe.py")
SPEC = importlib.util.spec_from_file_location("infrastructure_probe", FILE)
assert SPEC and SPEC.loader
probe = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(probe)


class ProbeContract(unittest.TestCase):
    def test_never_uses_shell_or_writes(self) -> None:
        text = FILE.read_text()
        self.assertNotIn("shell=True", text)
        self.assertNotIn("subprocess.Popen", text)
        self.assertNotIn("sudo", text.split("def run_fixed(")[1])
        self.assertNotIn("AWS_ACCESS_KEY_ID", text)
        self.assertNotIn("terraform apply", text)
        self.assertNotIn("docker.sock", text)

    def test_running_vm_without_unambiguous_lease(self) -> None:
        with patch.object(probe, "run_fixed", side_effect=lambda c: "running\n" if "domstate" in c else ""):
            self.assertEqual(probe.vm_state(), "running")
            self.assertEqual(probe.ip_from_lease(), "")

    def test_dhcp_lease_must_be_unique(self) -> None:
        def run(c):
            return "192.168.122.5/24\n192.168.122.6/24" if "net-dhcp-leases" in c else None
        with patch.object(probe, "run_fixed", side_effect=run):
            self.assertEqual(probe.ip_from_lease(), "")

    def test_unknown_guest_ip_does_not_make_request(self) -> None:
        with patch.object(probe.urllib.request, "build_opener") as mock_open:
            self.assertEqual(probe.guest_health("8.8.8.8"), "unknown")
            self.assertEqual(probe.guest_health(""), "unknown")
            mock_open.assert_not_called()

    def test_probe_outputs_fixed_fields_only(self) -> None:
        with (
            patch.object(probe, "vm_state", return_value="stopped"),
            patch.object(probe, "floci", return_value="up"),
        ):
            output = probe.collect()
        self.assertEqual(output["source"], "local-readonly-probe")
        self.assertEqual(output["health"], "unknown")
        self.assertEqual(output["vm_ip"], "")
        self.assertEqual(set(output), {"schema", "source", "observed_at", "floci", "vm", "health", "vm_ip"})


if __name__ == "__main__":
    unittest.main()
