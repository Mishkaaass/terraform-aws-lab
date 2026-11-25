# v1.0.0 acceptance and evidence

Publish the first stable reviewer release only after all of the following are true.

## Automated checks

- [ ] Terraform `fmt`, `validate`, mock-provider tests and Python venv unit tests pass.
- [ ] The Docker Studio image builds from the pinned base digest on a clean runner, serves only allowlisted static UI, denies sensitive paths, and does not start Floci.
- [ ] Disposable Floci integration can apply, run strict live `make local-verify`, confirm `No changes`, simulate guarded drift, repair it and destroy all ephemeral resources.
- [ ] VM Terraform validation passes without creating a guest.
- [ ] Trivy IaC and Gitleaks secret scans pass.
- [ ] Green CI on **both the PR head and merged `main`**.

## Reviewer experience

- [ ] A clean clone can run `make requirements`, `make setup`, `make studio`.
- [ ] A clean Docker-equipped machine can run `make studio-docker` without mounting any repo state or cloud credentials.
- [ ] README states the architecture, why each component exists, the recommended venv route and optional external CLI requirements.
- [ ] Browser walkthrough clearly distinguishes simulation, real Floci APIs and an optional stopped KVM guest.
- [ ] The public GitHub repo has description, appropriate topics and required branch-protection checks configured. **These account settings require manual confirmation in GitHub.**

## Release

- [ ] Merge `release/v1.0.0-hardening` into `main` only after CI green.
- [ ] Confirm merged-main CI green.
- [ ] Create signed/annotated `v1.0.0` tag or GitHub Release from the reviewed commit.
- [ ] Link Release Notes to `CHANGELOG.md` and include the README one-minute setup.

**Important:** A green pipeline is evidence for the specific implemented controls only. Do not describe Floci as a real AWS runtime or claim production certification. Never delete personal Terraform state to manufacture a clean demo.

## GitHub commands (run on your authenticated workstation)

```bash
cd ~/projects/terraform-aws-lab
git fetch origin main
git switch main
git pull --ff-only origin main
gh repo edit Mishkaaass/terraform-aws-lab --description "Hands-on Terraform AWS lab: interactive architecture, safe Floci emulation, reproducible venv/Docker Studio and drift recovery."
gh repo edit Mishkaaass/terraform-aws-lab --add-topic terraform --add-topic infrastructure-as-code --add-topic aws --add-topic devops --add-topic security --add-topic docker --add-topic python
gh release create v1.0.0 --target main --title "Terraform AWS Lab v1.0.0" --notes-file CHANGELOG.md
```

Only run the final `gh release create` once the reviewed and merged `main` CI is green. If a tag/release already exists, inspect it first instead of overwriting.
