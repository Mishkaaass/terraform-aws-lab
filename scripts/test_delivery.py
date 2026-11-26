"""Offline tests for the CI/CD contract and sensitive-path packaging guard."""
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("package_release", ROOT / "scripts/package-release.py")
PACKAGE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PACKAGE)


class DeliveryContract(unittest.TestCase):
    def test_only_committed_safe_source_is_eligible(self):
        for name in ("README.md", "environments/aws/.terraform.lock.hcl",
                     "environments/aws/terraform.tfvars.example", "modules/network/main.tf"):
            self.assertTrue(PACKAGE.allowed(name), name)
        for name in ("terraform.tfstate", "x/terraform.tfstate.backup", "a.tfplan",
                     ".terraform/providers/a", ".git/config", "environments/aws/local.tfvars",
                     ".env", ".env.local", "private.pem", "reports/output.txt"):
            self.assertFalse(PACKAGE.allowed(name), name)

    def test_delivery_is_bound_to_verified_main(self):
        flow = (ROOT / ".github/workflows/cd.yml").read_text()
        for marker in ("workflow_run.conclusion == 'success'",
                       "workflow_run.event == 'push'",
                       "workflow_run.head_branch == 'main'",
                       "workflow_run.head_repository.full_name == github.repository",
                       "persist-credentials: false", "sbom: true", "provenance: mode=max",
                       "package-release.py", "scan-image.sh", "smoke-studio-image.sh",
                       "Publish verified source bundle", "actions: read", "packages: write"):
            self.assertIn(marker, flow)
        self.assertLess(flow.index("Pull, scan and smoke"), flow.index("Recheck main before promoting"))
        self.assertNotIn("id-token: write", flow)
        self.assertNotIn("terraform apply", flow)
        self.assertNotIn("aws-apply", flow)

    def test_smoke_does_not_connect_to_external_network_or_host(self):
        smoke = (ROOT / "scripts/smoke-studio-image.sh").read_text()
        for marker in ("--network none", "--read-only", "--cap-drop ALL",
                       "--user 65532:65532", "no-new-privileges", "/terraform.tfstate"):
            self.assertIn(marker, smoke)
        for marker in ("--privileged", "--network host", "docker.sock", "--publish"):
            self.assertNotIn(marker, smoke)


if __name__ == "__main__":
    unittest.main()
