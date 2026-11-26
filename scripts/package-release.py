#!/usr/bin/env python3
"""Package only the exact committed source; never include working-tree state."""
import hashlib
import re
import subprocess
import sys
import tarfile
from pathlib import Path

PREFIX = "terraform-aws-lab/"
ROOT = Path(__file__).resolve().parents[1]


def allowed(name):
    parts = Path(name).parts
    lower = name.lower()
    return (
        not any(part in {".git", ".terraform", ".venv", "__pycache__", "reports", "artifacts"}
                for part in parts)
        and not any(marker in lower for marker in (".tfstate", ".tfplan", ".pem", ".key"))
        and not lower.endswith((".tfvars", ".tfvars.json", ".env"))
        and not any(part.startswith(".env.") for part in parts)
    )


def main():
    if len(sys.argv) != 3 or not re.fullmatch("[0-9a-f]{40}", sys.argv[1]):
        raise SystemExit("Usage: package-release.py COMMIT_SHA NEW_OUTPUT_DIRECTORY")
    sha, directory = sys.argv[1:]
    out = Path(directory).resolve()
    if ROOT == out or ROOT in out.parents or out.exists():
        raise SystemExit("Output must be a new directory outside the checkout")
    head = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
    ).strip()
    if head != sha:
        raise SystemExit("Wrong checked-out commit")
    names = subprocess.check_output(
        ["git", "ls-tree", "-r", "--name-only", "-z", sha], cwd=ROOT
    ).decode().split("\0")
    if not all(allowed(name) for name in names if name):
        raise SystemExit("Sensitive or generated path in committed source; refusing delivery")
    out.mkdir()
    archive = out / ("terraform-aws-lab-" + sha[:12] + ".tar.gz")
    subprocess.run(
        ["git", "archive", "--format=tar.gz", "--prefix=" + PREFIX,
         "-o", str(archive), sha], cwd=ROOT, check=True
    )
    with tarfile.open(archive, "r:gz") as package:
        for item in package.getmembers():
            if not item.name.startswith(PREFIX.rstrip("/") + "/") and item.name != PREFIX.rstrip("/"):
                raise SystemExit("Archive prefix mismatch")
            if not (item.isfile() or item.isdir()):
                raise SystemExit("Non-regular source archive member")
            if not allowed(item.name) or ".." in Path(item.name).parts:
                raise SystemExit("Unsafe archive member")
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (out / "SHA256SUMS").write_text(f"{digest}  {archive.name}\n")
    print("[PASS] Exact committed source bundle + SHA256 checksum")


if __name__ == "__main__":
    main()
