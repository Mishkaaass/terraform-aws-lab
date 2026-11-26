# Run requirements — new reviewers

Pick **one** of the two browser options; they serve the **same source assets**.

| Path | Install first | Command | Changes to your machine |
| --- | --- | --- | --- |
| **Recommended: Python .venv** | Python **3.11+**, `python3-venv` (when required by OS), Git, Make, browser | `make requirements`, `make setup`, `make studio` | Creates only `.venv/` in the clone; **no PyPI dependencies** |
| **Alternative: Docker UI** | Docker Engine/Desktop + Compose, Git and browser | `make studio-docker` | Builds browser-only image from pinned Python OCI image; no `.venv` needed |
| **Optional: real Floci lab** | Terraform **1.17.x**, AWS CLI v2, Docker/Compose to start Floci, curl | `make doctor`, `make test`, `make local-up` | Emulated VPC/state resources; `apply` and `drift` change local emulator |
| **Optional: Ubuntu KVM** | Linux with KVM, libvirt and additional guest dependencies | See [LOCAL_VM.md](LOCAL_VM.md) | Creates a real local VM only if you explicitly choose to |

**The Studio itself does not require Terraform, AWS, Docker or an AWS account.** `requirements.txt` is intentionally empty of packages because the HTTP server and probe use only Python's standard library. **Python virtual environments manage Python packages, not external command-line tools** such as Terraform, Docker, AWS CLI, Git or libvirt.

**Choose your operating system:** [Linux](linux.md) · [Windows / WSL 2](windows.md) · [macOS](macos.md). Linux is the CI reference environment. The Studio has a portable Python route on Linux/macOS and Docker Desktop route on Windows/macOS; the real CLI path on other hosts is subject to toolchain and architecture compatibility.

## Recommended .venv path

```bash
git clone https://github.com/Mishkaaass/terraform-aws-lab.git
cd terraform-aws-lab
make requirements
make setup
make studio
```

Open http://127.0.0.1:8765/. `make setup` creates/reuses **`.venv/bin/python`** without global package installation or internet downloads. `make studio` invokes that interpreter, creating the venv first if needed. No `source .venv/bin/activate` is required. For manual Python commands: `.venv/bin/python engineering-lab/probe.py`. `Ctrl+C` stops the foreground server.

If Ubuntu/Debian reports missing `ensurepip`, install `python3-venv` using your normal administrator-approved package manager, then rerun `make setup`. **Never use `sudo pip` or modify system Python packages.**

## Docker UI path (alternative)

```bash
git clone https://github.com/Mishkaaass/terraform-aws-lab.git
cd terraform-aws-lab
make studio-docker
```

Open http://127.0.0.1:8765/. The Compose `studio` service is profile-gated and serves only the four static UI assets. It has a pinned Python base image, an allowlisted build context, a read-only filesystem, non-root UID, dropped Linux capabilities, and a **127.0.0.1 host port**. No Terraform source, state, Git metadata, credentials, volumes or Docker socket are copied/mounted into the image. Docker binding inside the container uses `0.0.0.0` only so the **host-loopback-mapped** port can reach it. Docker is not a Python virtual environment; use **either** deployment.

Do not run Python-host Studio and Docker Studio simultaneously: both use host port **8765**. Stop one first; don't kill unrelated processes. Docker daemon access can be privileged on Linux — use your own trusted workstation or an isolated disposable VM; **never chmod 666** on `docker.sock`.

## Starting the real local IaC lab

Use a Linux shell (native Linux or Ubuntu WSL 2), or the optional macOS CLI prerequisites in [macOS setup](macos.md). The commands below do not use a real AWS account.

```bash
make doctor           # read-only diagnostic
make test             # mock-provider tests (no Docker or AWS)
make local-up         # reuse/start localhost Floci
make local-plan       # inspect changes, do not apply
make local-apply      # prompts before writing emulator state
make local-verify     # read-only strict API invariants
make local-drift      # intentional local tag change + guarded repair
```

This is not “inside the Python venv”: the `make` targets select Terraform 1.17.x externally using `scripts/terraform.sh`. `local-up` reuses an existing healthy Floci even without Docker daemon permissions. A running emulator may use an older image, so never recreate a healthy one without backing up and reviewing state.

**Free cloud option:** none is required. Real AWS is a separate, guarded, opt-in workflow that can incur charges. See [AWS_RUNBOOK.md](AWS_RUNBOOK.md).

## For reviewers and maintainers

- The Docker image is rebuilt locally from the pinned OCI index and fixed source files, not pulled as a custom unpublished image. This provides a reproducible browser UI across supported CPU architectures, subject to registry availability.
- The local `.venv` uses the reviewer's Python interpreter and is isolated from global pip packages. There are **zero third-party runtime dependencies**; the Python minor version can differ across supported systems.
- CI exercises venv setup and the container separately, verifies the static server's security controls, and runs the optional Floci infrastructure path in a disposable runner.
- For actual security boundaries, see [SECURITY.md](SECURITY.md).
