"""Exercise safety guards using fake executables; never contact AWS or Terraform."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ACCOUNT = "123456789012"


class GuardTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.log = self.home / "calls"
        self.env = {
            "HOME": str(self.home),
            "PATH": str(self.bin) + os.pathsep + "/usr/bin:/bin",
            "AWS_PROFILE": "lab-sandbox",
            "AWS_EXPECTED_ACCOUNT_ID": ACCOUNT,
            "MOCK_ARN": f"arn:aws:sts::{ACCOUNT}:assumed-role/sandbox/session",
            "MOCK_LOG": str(self.log),
        }
        self.executable("aws", """#!/bin/bash
printf 'aws:%s\n' "$*" >> "$MOCK_LOG"
[[ "$AWS_IGNORE_CONFIGURED_ENDPOINT_URLS" == true ]] || exit 9
printf '%s\t%s\n' "$AWS_EXPECTED_ACCOUNT_ID" "$MOCK_ARN"
""")
        self.executable("terraform", """#!/bin/bash
if [[ "$1" == version && "$2" == -json ]]; then
  printf '{"terraform_version":"1.17.2"}\n'
else
  printf 'tf:%s\n' "$*" >> "$MOCK_LOG"
fi
""")

    def executable(self, name, content):
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o700)

    def call(self, action="plan", **overrides):
        return subprocess.run(
            ["bash", str(ROOT / "scripts/aws-command.sh"), action],
            cwd=ROOT, env={**self.env, **overrides}, capture_output=True,
            text=True, stdin=subprocess.DEVNULL, timeout=10, check=False,
        )

    def test_inherited_flags_and_endpoint_overrides_block_before_any_call(self):
        for name, value in (
            ("TF_CLI_ARGS_apply", "-auto-approve"),
            ("TF_CLI_ARGS", "-input=false"),
            ("TF_DATA_DIR", "/tmp/unrelated"),
            ("TF_WORKSPACE", "unrelated"),
            ("TF_REATTACH_PROVIDERS", "{}"),
            ("AWS_ENDPOINT_URL_STS", "http://127.0.0.1:4566"),
            ("AWS_CONTAINER_CREDENTIALS_RELATIVE_URI", "/credentials"),
        ):
            with self.subTest(name=name):
                result = self.call(**{name: value})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(name, result.stderr)
                self.assertFalse(self.log.exists())

    def test_noninteractive_apply_and_destroy_refused(self):
        for action in ("apply", "destroy"):
            result = self.call(action, I_UNDERSTAND_AWS_CHARGES="YES",
                               CONFIRM_AWS_DESTROY="YES")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("interactive terminal", result.stderr)
            self.assertFalse(self.log.exists())

    def test_root_refused_before_terraform(self):
        result = self.call(MOCK_ARN=f"arn:aws:iam::{ACCOUNT}:root")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Root or unsupported", result.stderr)
        self.assertNotIn("tf:", self.log.read_text())

    def test_plan_passes_account_as_high_priority_cli_variable(self):
        result = self.call(TF_VAR_expected_account_id="999999999999")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.log.read_text()
        self.assertIn("-lockfile=readonly", calls)
        self.assertIn(f"plan -input=true -var=expected_account_id={ACCOUNT}", calls)
        self.assertNotIn("-auto-approve", calls)


if __name__ == "__main__":
    unittest.main()
