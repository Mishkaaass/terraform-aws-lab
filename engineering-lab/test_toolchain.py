#!/usr/bin/env python3
"""Run compatibility selector tests without real Terraform, cloud or Docker."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
WRAPPER = ROOT / "scripts" / "terraform.sh"


def mock_terraform(path: Path, version: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        '#!/bin/sh\n'
        'if [ "$1" = version ] && [ "$2" = -json ]; then\n'
        f'  printf \'{{"terraform_version":"{version}"}}\\n\'\n'
        'else\n'
        f'  printf \'FAKE-{version}: %s\\n\' "$*"\n'
        'fi\n'
    )
    path.chmod(0o700)


class ToolchainContract(unittest.TestCase):
    def run_fake(self, temp: Path) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env["HOME"] = str(temp)
        env["PATH"] = str(temp / "bin") + os.pathsep + "/usr/bin:/bin"
        return subprocess.run(
            ["bash", str(WRAPPER), "plan", "-input=false"],
            cwd=ROOT, env=env, check=False, capture_output=True,
            text=True, timeout=8,
        )

    def test_pinned_version_wins_over_old_system_terraform(self) -> None:
        with tempfile.TemporaryDirectory() as home:
            tmp = Path(home)
            mock_terraform(tmp / "bin" / "terraform", "1.16.6")
            mock_terraform(tmp / ".local/opt/terraform/1.17.2/terraform", "1.17.2")
            result = self.run_fake(tmp)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("FAKE-1.17.2: plan -input=false", result.stdout)

    def test_wrong_system_version_fails_without_running_a_plan(self) -> None:
        with tempfile.TemporaryDirectory() as home:
            tmp = Path(home)
            mock_terraform(tmp / "bin" / "terraform", "1.16.6")
            result = self.run_fake(tmp)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("[BLOCK] Found Terraform 1.16.6", result.stderr)
            self.assertNotIn("FAKE-", result.stdout)

    def test_make_targets_share_selector_and_browser_needs_only_python(self) -> None:
        makefile = (ROOT / "Makefile").read_text()
        self.assertIn("TF := bash scripts/terraform.sh", makefile)
        self.assertIn("studio: setup\\n\\t@.venv/bin/python engineering-lab/serve.py", makefile)
        self.assertIn("requirements:\\n\\t@bash scripts/requirements.sh", makefile)
        self.assertIn("setup:\\n\\t@bash scripts/setup-studio.sh", makefile)
        self.assertIn("studio-docker:\\n\\t@docker compose --profile studio up --build studio", makefile)
        self.assertIn("doctor:\n\t@bash engineering-lab/doctor.sh", makefile)
        self.assertNotIn("@terraform ", makefile)
        for path in ("scripts/drift-lab.sh", "scripts/verify-local.sh"):
            self.assertIn("scripts/terraform.sh", (ROOT / path).read_text())


if __name__ == "__main__":
    unittest.main()
