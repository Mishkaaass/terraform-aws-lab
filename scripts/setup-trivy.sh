#!/usr/bin/env bash
# CI-only: extract the scanner from the same reviewed image as OpsBoard.
set -Eeuo pipefail
: "${RUNNER_TEMP:?CI runner temp required}"
: "${GITHUB_PATH:?GitHub Actions required}"
image="docker.io/aquasec/trivy:0.76.2@sha256:8f6bb947dbc528902e11f2f5be52f7b519f6a39d5d148f41166f2040499768fb"
docker pull "$image"
docker image inspect "$image" --format '{{json .RepoDigests}}'
install -d "$RUNNER_TEMP/trivy-bin"
cid="$(docker create "$image")"
trap 'docker container rm "$cid" >/dev/null 2>&1 || true' EXIT
docker cp "$cid:/usr/local/bin/trivy" "$RUNNER_TEMP/trivy-bin/trivy"
chmod 0755 "$RUNNER_TEMP/trivy-bin/trivy"
"$RUNNER_TEMP/trivy-bin/trivy" --version | grep -Fx 'Version: 0.76.2'
echo "$RUNNER_TEMP/trivy-bin" >> "$GITHUB_PATH"
