# Linux — Terraform AWS Lab setup

Ubuntu/Debian is the reference environment. The browser Studio needs only Python 3.11+, Git and Make. The optional local Floci lab uses real Terraform CLI operations against an emulated AWS API, not real AWS infrastructure.

## Install the basic tools

On Ubuntu/Debian, install missing tools with your normal package manager after reviewing the changes:

```bash
sudo apt update
sudo apt install git make python3 python3-venv curl
```

Confirm `python3 --version` is at least 3.11; if not, use a supported distribution or a trusted user-scoped Python installation.

```bash
git clone https://github.com/Mishkaaass/terraform-aws-lab.git
cd terraform-aws-lab
make requirements
make setup
make studio
```

Open http://127.0.0.1:8765/. Ctrl+C stops Studio. No PyPI packages, AWS account or Docker daemon are needed for this path.

## Optional: Terraform / Floci hands-on exercises

Install [Terraform](https://developer.hashicorp.com/terraform/install) in the version specified by `.terraform-version` (currently 1.17.2), [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), and [Docker Engine + Compose](https://docs.docker.com/engine/install/) if you want to start the emulator. Verify downloaded binaries and use a trusted local Docker daemon. No AWS credentials or Docker socket mounts are needed.

In a second terminal in the same checkout:

```bash
make doctor
make test
make local-up
make local-plan
```

Inspect the plan before proceeding one command at a time:

```bash
make local-apply
make local-verify
make local-drift
```

Apply changes the local emulator and asks for approval; drift deliberately changes one local VPC tag and asks before repairing it. Do not share state or credentials. Do not run real-AWS targets for this exercise. See the [README](../README.md), [security model](SECURITY.md) and [run requirements](REQUIREMENTS.md).

Use `make local-down` only when finished with the emulator. Never delete Terraform state to fix a mismatch. The independent [KVM guest](LOCAL_VM.md) requires a suitable Linux host and is optional.
