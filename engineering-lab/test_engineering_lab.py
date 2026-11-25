#!/usr/bin/env python3
"""Offline contract checks for the reviewer-facing infrastructure decision lab."""
from __future__ import annotations

import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
LAB = ROOT / "engineering-lab"
MISSIONS = json.loads((LAB / "missions.json").read_text(encoding="utf-8"))
VALID_SAFETY = {"readonly", "interactive", "changes-emulator", "guarded-cloud"}


class EngineeringLabContract(unittest.TestCase):
    def test_schema_and_decision_count(self) -> None:
        self.assertEqual(MISSIONS["schema"], 1)
        self.assertGreaterEqual(len(MISSIONS["missions"]), 7)
        total = sum(len(m["phases"]) for m in MISSIONS["missions"])
        self.assertEqual(total, 21)
        self.assertEqual(len({m["id"] for m in MISSIONS["missions"]}), len(MISSIONS["missions"]))

    def test_each_phase_has_reason_proof_and_grounded_source(self) -> None:
        for mission in MISSIONS["missions"]:
            with self.subTest(mission=mission["id"]):
                self.assertEqual(len(mission["phases"]), 3)
                self.assertGreaterEqual(len(mission["evidence"]), 2)
                self.assertTrue(mission["story"])
                self.assertTrue(mission["debrief"])
                for ref in mission["paths"]:
                    self.assertTrue((ROOT / ref).is_file(), ref)
                for phase in mission["phases"]:
                    self.assertEqual(len(phase["choices"]), 3)
                    self.assertIn(phase["answer"], range(3))
                    self.assertIn(phase["safety"], VALID_SAFETY)
                    self.assertIn(phase["source"], mission["paths"])
                    self.assertTrue((ROOT / phase["source"]).is_file(), phase["source"])
                    for attr in ("question", "why", "proof", "hint", "command", "stage"):
                        self.assertTrue(str(phase[attr]).strip(), attr)

    def test_no_baked_in_credentials_or_mutation_in_browser(self) -> None:
        html = (LAB / "index.html").read_text(encoding="utf-8")
        js = (LAB / "app.js").read_text(encoding="utf-8")
        css = (LAB / "style.css").read_text(encoding="utf-8")
        self.assertIn('fetch("./missions.json"', js)
        self.assertNotIn("fetch('http", js)
        self.assertNotIn("child_process", js)
        self.assertNotIn("eval(", js)
        self.assertNotIn("localStorage", js)
        self.assertNotIn("@import", css)
        self.assertNotIn("https://fonts", css)
        self.assertIn("non-executing", js)
        self.assertIn("DESIGN SANDBOX", html)
        self.assertIn("SYSTEM MAP", html)
        self.assertIn("RUN THE REAL LAB", html)
        self.assertIn("INCIDENT CASES", html)
        self.assertIn('id="inspect-probe"', html)
        self.assertIn("STEP 3", html)
        self.assertIn("renderTopology", js)
        self.assertIn("renderDesign", js)
        self.assertIn("inspectProbe", js)
        for scenario in ("isolated", "endpoints", "exposed"):
            self.assertIn(f'data-preset="{scenario}"', html)
        for element in ("design-lesson", "step-purpose", "step-impact",
                        "step-expected", "next-checkpoint"):
            self.assertIn(f'id="{element}"', html)
        self.assertIn("function selectPreset(", js)
        self.assertIn("function renderSteps(", js)
        self.assertIn('id="copy-doctor"', html)
        doctor = (LAB / "doctor.sh").read_text(encoding="utf-8")
        self.assertIn("No sudo", doctor)
        self.assertIn("BLOCK", doctor)
        self.assertIn("This is a learning-model preview", js)
        self.assertIn('class="first-run"', html)
        self.assertIn("No AWS account or Docker needed", html)
        self.assertIn("EDUCATIONAL DESIGN LABELS", js)
        self.assertNotIn('"enable_compute = "+c.compute', js)
        self.assertNotIn('line(svg,222,113,222,364,"private")', js)
        self.assertIn('id="copy-doctor"', html)
        self.assertIn('id="reflection"', html)
        serve = (LAB / "serve.py").read_text(encoding="utf-8")
        self.assertIn("127.0.0.1", serve)
        self.assertIn("PUBLIC_FILES", serve)
        self.assertIn("Content-Security-Policy", serve)

    def test_repository_fixtures_are_simulations(self) -> None:
        self.assertIn("simulator", MISSIONS["disclosure"].lower())
        self.assertIn("not", MISSIONS["disclosure"].lower())
        ids = {m["id"] for m in MISSIONS["missions"]}
        self.assertTrue({"boot", "apparmor", "drift", "emulation", "network", "bootstrap", "delivery"}.issubset(ids))


if __name__ == "__main__":
    unittest.main()
