# Windows — Terraform AWS Lab setup

## 1. Recommended: Ubuntu WSL 2

On a supported Windows PC, if Ubuntu is not installed, open PowerShell as Administrator and run:

```powershell
wsl --install -d Ubuntu
```

Restart if Windows requests it, open Ubuntu once, create a non-root Linux user and verify `wsl -l -v` shows Ubuntu version 2. See [Microsoft's WSL installation guide](https://learn.microsoft.com/en-us/windows/wsl/install).

From now on, run the following in the **Ubuntu terminal**:

```bash
sudo apt update
sudo apt install git make python3 python3-venv curl
git clone https://github.com/Mishkaaass/terraform-aws-lab.git
cd terraform-aws-lab
make requirements
make setup
make studio
```

Python must be 3.11+. Open http://127.0.0.1:8765/ in your Windows browser (WSL localhost forwarding). No Docker or AWS account is required for this Studio. Stop with Ctrl+C. Keep the clone in the Ubuntu home directory rather than a mounted Windows filesystem.

## 2. Optional: real local Floci exercises

Install Terraform in the version specified by `.terraform-version`, and AWS CLI v2 **inside Ubuntu**, following [Linux setup](linux.md). Install [Docker Desktop](https://docs.docker.com/desktop/setup/install/windows-install/) on Windows, start it with Linux containers and the WSL 2 backend, and enable **Settings → Resources → WSL Integration** for your Ubuntu distribution. Do not install a second Docker daemon in WSL.

In Ubuntu, verify `docker info` and `docker compose version`, then in the repository:

```bash
make doctor
make test
make local-up
make local-plan
```

Only after reviewing the local plan, execute `make local-apply`, `make local-verify` and `make local-drift` one at a time. All API exercises use the local emulator. Do not use `make aws-apply` or configure real AWS credentials for training.

## 3. Alternative: native Windows browser Studio

If you have Git for Windows and Docker Desktop with Linux containers running, you can use PowerShell directly for the browser-only UI:

```powershell
git clone https://github.com/Mishkaaass/terraform-aws-lab.git
cd terraform-aws-lab
docker compose --profile studio up --build studio
```

Open http://127.0.0.1:8765/. Stop with Ctrl+C; run only one Studio at a time. The profile starts the isolated static UI, not Floci or Terraform. No host Python or AWS credentials are needed. This is not native PowerShell support for the Bash/Make IaC scripts.

## Boundaries

The optional [real KVM VM](LOCAL_VM.md) is a separate Linux KVM/libvirt exercise, not a required WSL feature. Use a suitable dedicated Linux host for it. Windows paths and full runtime on every CPU have not been independently tested by the Linux CI pipeline. If localhost forwarding or provider setup fails, use the reference Linux route instead of opening public ports, weakening security or deleting state.
