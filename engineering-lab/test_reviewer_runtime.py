#!/usr/bin/env python3
"""Offline reviewer setup contracts; never start Docker, Terraform or network."""
from __future__ import annotations

import os
from pathlib import Path
from unittest import TestCase
from unittest.mock import patch
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
LAB=ROOT/"engineering-lab"
sys.path.insert(0,str(LAB))
import serve


class ReviewerRuntimeContract(TestCase):
    def test_requirements_are_documented_and_stdlib_only(self) -> None:
        req=(ROOT/"requirements.txt").read_text()
        self.assertTrue(req)
        self.assertTrue(all(not row.strip() or row.lstrip().startswith("#")
                            for row in req.splitlines()))
        self.assertIn("make setup", (ROOT/"README.md").read_text())
        self.assertIn("make studio-docker", (ROOT/"README.md").read_text())

    def test_venv_is_required_for_make_studio(self) -> None:
        mk=(ROOT/"Makefile").read_text()
        self.assertIn("studio: setup\n\t@.venv/bin/python engineering-lab/serve.py", mk)
        self.assertIn("python3 -m venv .venv", (ROOT/"scripts/setup-studio.sh").read_text())
        self.assertIn(".venv/", (ROOT/".gitignore").read_text())

    def test_docker_build_has_no_repo_secrets_or_state(self) -> None:
        ignore=(ROOT/".dockerignore").read_text()
        self.assertEqual(ignore.splitlines()[2].strip(),"*")
        for name in ("serve.py","index.html","app.js","style.css","missions.json"):
            self.assertIn("!engineering-lab/"+name,ignore)
        for token in ("!.git/", "!environments/", "!reports/", "!*.tfstate"):
            self.assertNotIn(token,ignore)
        dockerfile=(ROOT/"docker/studio.Dockerfile").read_text()
        self.assertIn("FROM python:3.14-slim@sha256:22eafb370920ad8b429e0aec3fff433e0669968519f5d60469d83729c138b28b",dockerfile)
        self.assertIn("python -m pip uninstall --yes pip",dockerfile)
        self.assertIn("USER 65532:65532",dockerfile)
        self.assertNotIn("pip install",dockerfile)
        self.assertNotIn("COPY . ",dockerfile)
        compose=(ROOT/"compose.yaml").read_text()
        self.assertIn('profiles: ["studio"]',compose)
        self.assertIn('127.0.0.1:8765:8765',compose)
        self.assertIn("read_only: true",compose)

    def test_release_publisher_is_manual_and_gated(self) -> None:
        pub=(ROOT/"scripts/publish-release.sh").read_text()
        mk=(ROOT/"Makefile").read_text()
        self.assertIn("publish-release:",mk)
        self.assertIn("check-runs?per_page=100",pub)
        self.assertIn("git fetch --quiet origin main",pub)
        self.assertIn("publish v1.0.0",pub)
        self.assertIn("gh release create",pub)
        self.assertIn("GH_HOST=github.com gh api user --jq .login", pub)
        self.assertIn('[[ "$ACTIVE_USER" != "Mishkaaass" ]]', pub)
        self.assertNotIn("gh auth status >/dev/null", pub)
        for forbidden in ("terraform destroy", "docker compose down", "-auto-approve"):
            self.assertNotIn(forbidden,pub)

    def test_nonloopback_server_is_rejected_outside_container(self) -> None:
        from contextlib import redirect_stderr
        from io import StringIO
        with patch.dict(os.environ, {"INFRA_STUDIO_CONTAINER":""}):
            with patch.object(sys, "argv", ["serve.py", "--bind", "0.0.0.0"]):
                with redirect_stderr(StringIO()) as out:
                    with self.assertRaises(SystemExit) as exc:
                        serve.main()
        self.assertEqual(exc.exception.code, 2)
        self.assertIn("reserved for the isolated Docker",out.getvalue())


if __name__ == "__main__":
    unittest.main()
