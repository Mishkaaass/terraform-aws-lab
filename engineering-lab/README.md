# Engineering Dojo — reviewer guide

**A runnable learning experience, not a screenshot or a solved checklist.**

Start a local browser-only training experience with **seven incident missions and 21 engineering decisions**. Every decision asks for the next safe observation, a hypothesis, an intervention boundary or independent verification. Explanations, evidence and code references become visible after each answer. End each mission with your own written incident review and copy your notes.

## Launch in 20 seconds

Requirements: Python 3, a browser and this repository. **No AWS account, Terraform, Docker, KVM or elevated privileges required for the simulator.**

From the repository root:

```bash
python3 -m http.server 8765 --bind 127.0.0.1
```

Open **http://127.0.0.1:8765/engineering-lab/**. Stop the local server with Ctrl+C.

The simulator contains recorded evidence and design exercises. It does not probe a running VM, use credentials, execute shell commands, change state, persist progress or call an external server. Decisions and reflection text live in page memory until reset/reload. It uses local CSS/JS/JSON with no third-party assets.

## Missions

| # | Case | Engineering competency | Evidence type |
|---|---|---|---|
| 01 | VM is running but has no disk or DHCP lease | Guest-vs-host fault isolation; PCI/VirtIO | Replayed actual KVM incident |
| 02 | QEMU is blocked by AppArmor | Fix access without disabling security | Replayed actual KVM incident |
| 03 | VPC tag modified outside Terraform | Detect, scope and repair drift | Script-backed local Floci drill |
| 04 | Green Floci CI vs real AWS | Distinguish mocks, API emulator, real cloud | Source-based design |
| 05 | Private EC2 missing SSM path | Identity vs network reachability | Unimplemented architecture exercise |
| 06 | Booted guest vs ready application | Independent SSH, cloud-init, systemd, HTTP proof | Verified guest/host outputs |
| 07 | CI jobs fail despite working KVM | CI layer triage and honest evidence claims | Replayed formatting incident |

**How to learn rather than memorize:** For each question, state a hypothesis aloud before selecting an answer; compare your prediction with the stored evidence; inspect the linked exact source file; write a *fresh explanation* in the debrief without copying the provided text. Try again later and explain the wrong choices too. An earned point is not a substitute for explanation.

## Optional real, read-only validation on the lab owner's laptop

The browser does **not** run these commands. If the local KVM VM is up and you have appropriate host access, these are representative manual checks:

```bash
virsh -c qemu:///system dominfo tfaws-lab01
virsh -c qemu:///system domblklist tfaws-lab01 --details
virsh -c qemu:///system net-dhcp-leases default
terraform -chdir=environments/libvirt plan -input=false
```

Do **not** copy the owner's IP address into someone else's environment; obtain the guest IP from their local libvirt DHCP leases. The commands above are read-only but may access local virtualization metadata or refresh Terraform state during planning; avoid using an unknown work machine or a different Terraform state. See [LOCAL_VM.md](../docs/LOCAL_VM.md) for the entire runbook.

For emulator drift, [scripts/drift-lab.sh](../scripts/drift-lab.sh) is a **separate, optional hands-on lab**. It makes an out-of-band change *only* against localhost Floci, requires an existing local emulated VPC, checks the planned repair scope and asks for explicit approval before restoring. Do not substitute a real AWS endpoint.

## Evidence discipline

The **recorded** KVM outcome (Ubuntu boot, DHCP, SSH, `cloud-init status: done`, `lab-health.service: active`, guest/host `/health`, Terraform `No changes`) was observed on the original laptop. A new reviewer has not recreated that runtime simply by completing this browser exercise. Similarly, a passing Floci integration test does not prove production AWS network isolation, SSM connectivity, IAM enforcement or operating cost.

## Learning acceptance criteria

A reviewer can (1) run this without accounts or elevated privileges; (2) finish all 21 decision branches; (3) see why a chosen answer is right or wrong; (4) inspect direct links to actual repository evidence; (5) record and copy an independent incident explanation; (6) reset and replay scenarios safely; and (7) identify the border between emulation and verified runtime.

Automated content contract: `python3 -m unittest discover -s engineering-lab -p 'test_*.py'`. Static tests do not prove browser accessibility or live KVM behavior. The branch must receive a human browser walkthrough before it is considered fully accepted.

## An interviewer-ready five-minute demonstration

Open Mission 01. Explain why **running != booted**, read the initramfs evidence, identify the missing `vda` device, reject the incorrect label or DHCP fix, and describe the narrow `q35 → pc` mitigation **only for this host**, with independent proof. Then switch to Mission 04 and explain precisely what an emulator does not prove. Finally, read the source files, show the CI workflow, and answer without looking at the multiple-choice options:

> If the VM is green, but `/health` fails from the host, which three observations would you gather before changing Terraform, and why?

That final open-ended explanation is the point: **engineering judgment, not memorizing a button.**
