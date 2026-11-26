# CI/CD delivery runbook

The same six required CI job names remain protected. They cover Terraform format/validation/mock tests, Studio Docker smoke and image security, IaC scan, full-history Gitleaks, disposable Floci apply/verify/drift/destroy, and Linux VM static validation.

## After successful main CI

1. CD accepts only a successful main-push CI from this repository. It checks all six jobs of the triggering attempt and the exact current main commit.
2. The pinned Buildx action creates an **amd64** Studio image with SBOM and provenance in GHCR. A uniquely named candidate tag is not a verified release.
3. Trivy checks the exact registry digest: all CRITICAL findings and fixable HIGH findings block; unfixed HIGH findings are reported and require review. Scanner failures block.
4. A fresh non-root, read-only container with no network, host mounts or published ports tests the static HTTP allowlist and security headers. The source revision label must match the tested commit.
5. CD rechecks main, promotes the verified digest to `sha-<commit>` and `latest`, and uploads the reviewed source archive, SHA256SUMS and delivery.json for 30 days.

An unsuccessful scan cannot authorize promotion. Candidate tags may remain in GHCR for investigation; they are not approved artifacts. The latest tag is mutable; use the digest recorded in delivery.json for reproducibility. GitHub's registry visibility may be private by default; the owner can explicitly review package access. No public registry visibility is assumed. Stable GitHub Release tags are not changed automatically.

## Verify evidence

Open the [CD workflow](https://github.com/Mishkaaass/terraform-aws-lab/actions/workflows/cd.yml), choose a successful run, and download its artifact. In the extracted artifact directory run `sha256sum -c SHA256SUMS` (macOS: `shasum -a 256 -c SHA256SUMS`). Inspect delivery.json for the commit and image digest. To verify an accessible registry image, use `docker buildx imagetools inspect IMAGE@sha256:DIGEST` with the recorded reference. The SBOM and provenance are Buildx attestations, not a signature or production certification.

For local testing, the original `make studio` and `make studio-docker` remain available, including native build paths on compatible Apple silicon systems. The published image is currently Linux/amd64 only; cross-architecture publication is not claimed.

## Real AWS remains manual

The pipeline never invokes real AWS, never requests cloud identity tokens, and does not create cloud resources or publish Terraform state. The reviewed source bundle includes the separately guarded AWS example root, not deployed infrastructure. Follow [AWS_RUNBOOK.md](AWS_RUNBOOK.md) only in a dedicated sandbox with deliberate approval and cost controls.
