#!/usr/bin/env python3
"""Release README contract: real in-repo UI image and truthful public badges."""
from __future__ import annotations

import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
README = ROOT / "README.md"
SCREENSHOT = ROOT / "docs/assets/infrastructure-studio-system-map.png"


class ReadmePresentationTest(unittest.TestCase):
    def test_intro_precedes_actual_project_screenshot(self) -> None:
        readme = README.read_text(encoding="utf-8")
        title = readme.index("# Terraform AWS Lab")
        intro = readme.index("A hands-on Infrastructure as Code platform")
        author = readme.index("*Developed by Moshe Bogo*")
        ci = readme.index("[![CI]")
        release = readme.index("[![Release]")
        screenshot = readme.index(
            "![Infrastructure Studio — interactive Terraform AWS network"
        )
        quickstart = readme.index("## Start in 60 seconds")
        self.assertTrue(title < intro < author < ci < screenshot < quickstart)
        self.assertTrue(author < release < screenshot)

    def test_ci_and_cd_claims_are_distinct(self) -> None:
        readme = README.read_text(encoding="utf-8")
        self.assertIn("actions/workflows/ci.yml/badge.svg", readme)
        self.assertIn("img.shields.io/github/v/release", readme)
        self.assertIn("CD-manual%20opt--in%20only", readme)
        self.assertIn("does not deploy to AWS", readme)
        self.assertIn("docs/AWS_RUNBOOK.md", readme)

    def test_committed_screenshot_is_real_png(self) -> None:
        self.assertTrue(SCREENSHOT.is_file(), "Commit the actual Studio screenshot")
        data = SCREENSHOT.read_bytes()
        self.assertTrue(data.startswith(b"\x89PNG\r\n\x1a\n"))
        width, height = struct.unpack(">II", data[16:24])
        self.assertGreaterEqual(width, 1200)
        self.assertGreaterEqual(height, 720)
        self.assertGreater(len(data), 10000)

    def test_original_setup_and_technical_content_preserved(self) -> None:
        readme = README.read_text(encoding="utf-8")
        for term in (
            "make setup", "make studio", "make test", "make local-plan",
            "make local-verify", "make local-drift", "mermaid",
            "docs/REQUIREMENTS.md",
        ):
            self.assertIn(term, readme)


if __name__ == "__main__":
    unittest.main()
