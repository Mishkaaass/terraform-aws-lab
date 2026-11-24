# Security audit — 2026-11-24

**Scope:** source review of public `Mishkaaass/ci-cd-lab` main (`f89d93e`), public `Mishkaaass/terraform-aws-lab` main (`12b1ab9`), and the new Engineering Dojo draft PR #4. This is an **offline review**, not a penetration-test certificate or an inspection of any end-user's running machine. GitHub CI status was checked for the named commits. No user machine, Terraform state, libvirt volume, Docker daemon or first-project source was modified.

## Executive decision

**Do not claim “impossible to hack”, “fully secure”, or “production certified”.** The training UI can be made low-risk, but the full demos use privileged Docker/libvirt and depend on downloaded packages and images. An unknown reviewer's host should not run elevated demonstrations by default.

## Findings and tracking

| ID | Severity | Finding and concrete evidence | Action / status |
|---|---|---|---|
| SA-01 | HIGH when exposed | Draft UI originally recommended `python3 -m http.server 8765 --bind 127.0.0.1` in **repository root**. Generic file serving can disclose `.git/`, Terraform state, and files outside the intended UI when URL access is available; Terraform state can contain sensitive data. | **Fixed in PR #4:** `engineering-lab/serve.py` binds loopback, uses an explicit file allowlist, no directory listing, validates Host/Origin, adds CSP and anti-framing/no-sniff/no-store headers, and refuses symlinked public assets. New direct HTTP tests cover forbidden paths. |
| SA-02 | HIGH architecture risk | The first project's `unified_console/server.py` requires a **viewer** token for `POST /api/showcase/start`; with an opted-in supervisor, this queues fixed Docker/GitOps actions. `showcase.py` can require `sudo` for Docker and run scripts. Not arbitrary command injection in inspected implementation, but **read access and operational control share a token**. | **Open / first project unchanged:** separate an operator-only scoped credential and explicit terminal approval for each state-changing drill. Do not expose the service to LAN/Internet. |
| SA-03 | HIGH supply-chain class | First-project demo uses unprivileged-local code to invoke `sudo docker compose` and potentially creates kind/Argo CD. Docker daemon control is root-equivalent on conventional installations. Scripts install pip dependencies from PyPI and pull Docker images. | **Open:** treat code/image updates as high trust, pin verified artifact digests and dependency hashes, use disposable VM for untrusted reviewers, never ask a reviewer to grant host-wide Docker access for mere browser learning. |
| SA-04 | MEDIUM-HIGH | Second project's `compose.yaml` pulls `floci/floci:latest` without a digest. First project has floating Docker tags (`postgres:18-alpine`, `nginx:stable-alpine3.24`, `python:3.14-slim`); GitOps installation refers to an Argo CD version tag whose downloaded manifest isn't independently digest-verified. | **Open:** pin audited immutable digests and run update/scanner policy. Do not invent digests. |
| SA-05 | MEDIUM guest risk | `environments/libvirt/cloud-init.yaml.tftpl`: `devops` is SSH-key-only and password locked (good), but has `NOPASSWD:ALL` sudo inside guest; the demo health endpoint binds guest `0.0.0.0:8080` without auth. Default libvirt NAT is not a fully isolated/hostile-code sandbox. | **Open:** use less privileged guest admin where possible; require preflight proof that libvirt and VNC are loopback/NAT scoped; do not run untrusted guest workloads on a sensitive host. |
| SA-06 | MEDIUM | First-project `app.py` exposes Swagger at `/docs`, which allows jsdelivr assets in its local CSP exception. External scripts are a supply-chain attack surface on the app's origin. | **Open:** prefer locally hosted Swagger assets or disable docs in review/production modes. |
| SA-07 | MEDIUM | All published localhost endpoints rely on successful binding to `127.0.0.1`. A reviewer may rerun a modified or common server with `0.0.0.0`, opening unintended network access; WSL/host forwarding settings also matter. | **Open:** enforce loopback in reviewed code, instruct users never to publish ports, and validate actual listening addresses. |
| SA-08 | LOW / evidence limit | Both projects have CI checks for secrets/scans/tests and bounded web routes, but green CI cannot prove absence of vulnerabilities in the guest OS, host Docker/libvirt, dependencies, browsers, or an unseen local configuration. | **Open by nature:** independent host hardening, isolated runtime tests and periodic patching remain required. |

### Positive code controls confirmed

- Project 1's unified console binds to **127.0.0.1**, validates Host and Origin, gates private reads with a strong random Bearer token, has a restricted HTTP action allowlist, stores its token file as user-private `0600`, and exposes sanitized fixed log lines. Its FastAPI middleware requires viewer/operator roles and turns deployment operations off by default.
- Project 1 Docker demo ports are published to loopback; its Kubernetes Deployment runs non-root, disables service-account token mounting and privilege escalation, drops Linux capabilities, uses seccomp and restricts filesystem writes.
- Project 2 Floci AWS endpoints target **127.0.0.1:4566**, fake credentials are local-only, default Compose omits the Docker socket, the real AWS root has a separate expected-account guard, and the Linux guest uses a key rather than a login password. Its VNC listener is loopback.
- Both main branches had green CI on inspected commits. This does **not** prove deployment safety on an external computer.

### High-security reviewer policy

1. **Safest mode:** run only the Engineering Dojo allowlisted static browser UI using `python3 engineering-lab/serve.py`. Do not run `python3 -m http.server` at repository root.
2. **Privileged mode (optional, owner-only):** run Docker/Argo/KVM demos only on an isolated, disposable development VM and only after reviewing the exact branch/commit and planned changes. Do not give arbitrary viewers operator control or a Docker socket.
3. Use localhost exclusively. Verify local listeners with `ss -ltnp`. Keep private SSH keys, kubeconfig, personal AWS credentials and `*.tfstate` out of shared web roots and Git.
4. Never execute copy-pasted `curl | sh`; avoid globally disabling AppArmor; never make automated `terraform destroy` available from a web UI.
5. Lock dependencies and image digests, rerun Trivy/Gitleaks/pip-audit, perform adversarial browser/API checks and security regression tests before any release.

## Validation boundaries

Review included source-level inspection of both repository file trees, service/router code, access controls, launcher scripts, Docker Compose and Dockerfiles, GitOps/Kubernetes manifests, Terraform provider boundaries and state-handling, GitHub CI/CD configuration, and the new UI. Repo 1 was **not changed**; PR #4 is intentionally **draft** and should not merge until its updated security checks and a real browser review succeed. The **host's actual listening sockets, sudoers, iptables/nftables, Docker daemon mode, WSL forwarding, SSH keys, downloaded binaries and unknown local files were not accessible** from this session and therefore are **not certified**.

Official security references: [Docker daemon security](https://docs.docker.com/engine/security/), [Terraform state sensitivity](https://developer.hashicorp.com/terraform/language/manage-sensitive-data), and [Python http.server warning](https://docs.python.org/3/library/http.server.html).
