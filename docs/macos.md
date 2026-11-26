# macOS — Terraform AWS Lab setup

## 1. Native browser Studio (Intel / Apple silicon)

Install [Python 3.11+](https://www.python.org/downloads/) and Git/Make via Apple Command Line Tools. If needed, `xcode-select --install` opens Apple's installer. If Homebrew is already installed, `brew install python` is another option.

```bash
python3 --version
git clone https://github.com/Mishkaaass/terraform-aws-lab.git
cd terraform-aws-lab
make requirements
make setup
make studio
```

Open http://127.0.0.1:8765/. Stop with Ctrl+C. This is a standard-library Python UI; no Docker, Terraform, AWS account or system-wide Python packages are required. Do not reuse a venv copied from another operating system or architecture.

## 2. Alternative: Docker Desktop Studio

Install and start [Docker Desktop for Mac](https://docs.docker.com/desktop/setup/install/mac-install/) for your CPU architecture (Apple silicon or Intel), on a supported macOS version. Stop the Python Studio first. In the same repository:

```bash
docker info
docker compose version
make studio-docker
```

Open http://127.0.0.1:8765/. The Studio container runs with a read-only filesystem and no cloud credentials or Docker socket mount. It does not start Floci.

## 3. Optional native Terraform / Floci route

Linux is the reference runtime. For an optional native Mac trial, install [Terraform](https://developer.hashicorp.com/terraform/install) at the version in `.terraform-version` (currently 1.17.2), [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), Docker Desktop and GNU utilities. Select downloads for your actual CPU architecture and verify official checksums. If Homebrew is already installed, install Bash and coreutils, then select their commands **in this terminal only**:

```bash
brew install bash coreutils
export PATH="$(brew --prefix bash)/bin:$(brew --prefix coreutils)/libexec/gnubin:$PATH"
```

Check the local Docker context points to your own Docker Desktop engine, not a remote or production daemon. Then from the repository:

```bash
make doctor
make test
make local-up
make local-plan
```

Do not continue if Terraform reports a provider platform or lockfile mismatch. Do not edit or regenerate the lockfile merely to bypass a failure. Use a dedicated Ubuntu VM or Linux lab host and the [Linux instructions](linux.md) as the reference fallback. Only after a successful compatible local plan, run `make local-apply`, `make local-verify` and `make local-drift` individually with the documented approval gates.

No real AWS account is needed; don't run the real-AWS targets. The optional KVM guest requires a suitable Linux KVM/libvirt host; Docker Desktop's Linux VM is not a substitute. Native Mac runtime and all Intel/ARM combinations have not been independently verified. Keep loopback bindings and private Terraform state intact.
