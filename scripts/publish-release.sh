#!/usr/bin/env bash
# One-time, explicitly confirmed GitHub release publisher.
# Never alters Terraform state, Floci, AWS, Docker, KVM or the working tree.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
REPO="Mishkaaass/terraform-aws-lab"
TAG="v1.0.0"

for tool in git gh python3; do
  command -v "$tool" >/dev/null 2>&1 || { echo "[BLOCK] Missing $tool" >&2; exit 2; }
done
# gh auth status can exit nonzero when an INACTIVE account has an expired
# credential, even if the active account has valid access. Verify the actual
# API identity instead; fail closed if the selected token belongs to someone
# other than the expected repository owner.
if ! ACTIVE_USER="$(GH_HOST=github.com gh api user --jq .login 2>/dev/null)"; then
  echo '[BLOCK] GitHub CLI cannot reach github.com API using its active credentials.' >&2
  echo '[INFO] Check the active account with: gh auth status -h github.com' >&2
  exit 2
fi
if [[ "$ACTIVE_USER" != "Mishkaaass" ]]; then
  echo "[BLOCK] GitHub CLI is using $ACTIVE_USER, expected Mishkaaass. No changes made." >&2
  exit 2
fi
echo "[OK] Active GitHub API identity: $ACTIVE_USER"
[[ "$(gh repo view --json nameWithOwner --jq .nameWithOwner)" == "$REPO" ]] || {
  echo "[BLOCK] Current GitHub repo is not $REPO" >&2; exit 2;
}
[[ "$(git branch --show-current)" == "main" ]] || {
  echo '[BLOCK] Switch to main before publishing.' >&2; exit 2;
}
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || {
  echo '[BLOCK] Tracked local changes exist. Commit or review them first.' >&2; exit 2;
}

git fetch --quiet origin main
SHA="$(git rev-parse HEAD)"
REMOTE="$(git rev-parse origin/main)"
[[ "$SHA" == "$REMOTE" ]] || {
  echo '[BLOCK] Local main does not match origin/main; run git pull --ff-only origin main.' >&2
  exit 2
}

echo "===== SIX REQUIRED GITHUB QUALITY CHECKS ====="
CHECKS_JSON="$(gh api "repos/$REPO/commits/$SHA/check-runs?per_page=100")"
printf '%s' "$CHECKS_JSON" | python3 -c '
import json,sys
runs=json.load(sys.stdin).get("check_runs",[])
wanted=[
"Terraform format / validation / mock tests",
"Studio Docker reproducibility / static security smoke",
"Floci AWS API integration (apply / verify / destroy)",
"Local Linux VM / Terraform validation",
"Trivy IaC security scan",
"Gitleaks secret scan (full history)",
]
for name in wanted:
    items=[r for r in runs if r.get("name")==name]
    ok=bool(items) and all(r.get("status")=="completed" and r.get("conclusion")=="success" for r in items)
    print(("[PASS] " if ok else "[BLOCK] ")+name)
    if not ok:
        sys.exit(2)
if len(wanted)!=6:
    sys.exit(2)
'
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "[BLOCK] Release $TAG already exists. Review it; do not replace automatically." >&2
  exit 2
fi
echo
echo "[READY] main=$SHA; no existing $TAG release; six green checks."
echo "[INFO] Next actions change GitHub repo description/topics and publish a public release."
read -r -p "Type 'publish v1.0.0' to authorize GitHub metadata + release: " APPROVAL
[[ "$APPROVAL" == "publish v1.0.0" ]] || { echo '[STOP] No GitHub changes made.'; exit 0; }

gh repo edit "$REPO" \
  --description "Hands-on Terraform AWS lab with interactive architecture, Floci IaC emulation, isolated venv/Docker Studio and guarded drift recovery." \
  --add-topic terraform --add-topic infrastructure-as-code \
  --add-topic aws --add-topic devops --add-topic security \
  --add-topic docker --add-topic python
gh release create "$TAG" --repo "$REPO" --target "$SHA" \
  --title "Terraform AWS Lab v1.0.0" --notes-file CHANGELOG.md
echo "[PASS] Published $TAG from reviewed commit $SHA"
echo "[INFO] Verify main branch protection/required checks in GitHub Settings separately."
