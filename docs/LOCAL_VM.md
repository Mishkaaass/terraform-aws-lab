# Lab 3: Real Linux VM via Terraform + libvirt (free, local only)

This lab creates **one Ubuntu 24.04 LTS guest** using KVM/QEMU/libvirt. It does not touch AWS, Floci, Docker or any other repository. The guest is **1536 MiB RAM, 2 vCPUs, an 8 GiB sparse root disk**, cloud-init SSH-public-key login, and a systemd-managed Python /health endpoint.

**Boundaries:** Existing libvirt network `default` uses NAT and may permit guest internet egress; this is *not* a fully isolated production network. No new bridges, firewall policies, default routes or services on the host are modified. Terraform creates its own project storage pool `tfaws-lab` under `/var/lib/libvirt/images/tfaws-lab`; the existing `default` pool is not required. No cloud charges.

## Host preflight (read-only)

```bash
sudo timeout 10s virsh -c qemu:///system list --all
sudo timeout 10s virsh -c qemu:///system net-list --all
sudo timeout 10s virsh -c qemu:///system pool-list --all
sudo timeout 10s virsh -c qemu:///system dominfo tfaws-lab01 || true
sudo timeout 10s virsh -c qemu:///system pool-info tfaws-lab || true
id -nG
```

Stop if the proposed domain `tfaws-lab01` or pool `tfaws-lab` already exists outside Terraform state. The Terraform pool is separate; only the existing **network** `default` is reused.

**Provider permissions:** Running Terraform against `qemu:///system` requires permission to the libvirt system socket. On a personal dev laptop, membership of the `libvirt` group is conventional but **grants privileged virtualization management access**. If you deliberately accept this, run `sudo usermod -aG libvirt "$USER"`, then log out/in (or start a new group-enabled login session). Test `virsh -c qemu:///system list --all` *without sudo*. Do not run `sudo terraform` (it would create root-owned state and mix credentials).

## Download and validate a real Ubuntu cloud image

```bash
set -Eeuo pipefail
IMAGE_DIR="$HOME/.cache/terraform-aws-lab/images"
mkdir -p "$IMAGE_DIR"
curl -fL --retry 3 --output "$IMAGE_DIR/noble-server-cloudimg-amd64.img.part" \
  https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
curl -fL --retry 3 --output "$IMAGE_DIR/SHA256SUMS" \
  https://cloud-images.ubuntu.com/noble/current/SHA256SUMS
mv "$IMAGE_DIR/noble-server-cloudimg-amd64.img.part" "$IMAGE_DIR/noble-server-cloudimg-amd64.img"
(cd "$IMAGE_DIR" && grep -E '[ *]noble-server-cloudimg-amd64\.img$' SHA256SUMS | sha256sum -c -)
```

For stronger supply-chain assurance, check Ubuntu's signed checksums via an independently verified Canonical signing key. This exercise verifies the downloaded image against Ubuntu's HTTPS checksum manifest; it does not authenticate the manifest independently.

## Prepare a dedicated public SSH key

```bash
# Use an existing dedicated lab key if present; never overwrite it.
test -f "$HOME/.ssh/terraform-lab.pub" || ssh-keygen -t ed25519 -f "$HOME/.ssh/terraform-lab" -C "terraform-libvirt-lab"
export TF_VAR_ssh_public_key="$(cat "$HOME/.ssh/terraform-lab.pub")"
```

The **public** key is injected into the guest; the private key remains in `~/.ssh/terraform-lab`. SSH password authentication is disabled.

## Preview first, then provision explicitly

```bash
cd ~/projects/terraform-aws-lab
export PATH="$HOME/.local/opt/terraform/1.17.2:$PATH"
terraform -chdir=environments/libvirt init -input=false
terraform -chdir=environments/libvirt validate -no-color
terraform -chdir=environments/libvirt plan -input=false
# Read the plan; do NOT use auto-approve.
terraform -chdir=environments/libvirt apply
```

The Terraform state under `environments/libvirt` is local-only and gitignored. Do not publish it.

## Verify a real running guest

```bash
sudo virsh -c qemu:///system list --all
sudo virsh -c qemu:///system net-dhcp-leases default
sudo virsh -c qemu:///system domifaddr tfaws-lab01 --source lease
```

Identify the guest's DHCP address from the *libvirt* network lease list (do not guess). Then run:

```bash
ssh -i "$HOME/.ssh/terraform-lab" devops@GUEST_IP 'cloud-init status --wait; systemctl is-active lab-health'
curl -fsS --max-time 5 http://GUEST_IP:8080/health
terraform -chdir=environments/libvirt plan -input=false
```

Expected: VM running, `cloud-init` completed, `lab-health` active, JSON `status=ok`, and a second plan showing no changes.

**Cleanup only with deliberate approval:** `terraform -chdir=environments/libvirt destroy` shows what will be deleted and prompts before removing *only the Terraform-managed VM and volumes*. It is destructive to this guest's data. The pool's backing directory is deliberately not deleted by Terraform. It must never run automatically from CI.

## What CI proves vs what only your laptop proves

CI runs `terraform fmt` and `terraform validate` without needing `/dev/kvm`. Your laptop then proves real OS boot, DHCP, SSH and systemd via runtime commands. This separation is deliberate.
