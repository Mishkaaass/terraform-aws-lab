# Infrastructure Studio — the guided learning interface

**Goal:** understand a Terraform/AWS-style infrastructure design, experiment safely, then verify an actual local emulator. Start with **Python 3 only**:

```bash
cd terraform-aws-lab
make studio
```

Open **http://127.0.0.1:8765/**. Stop with `Ctrl+C`. If the address is already in use, open the existing server instead of starting another.

## What to do in each tab

| Tab | Your first action | What you learn |
| --- | --- | --- |
| **System Map** | Click the VPC, then public/private subnets, SG and IAM | The actual modules, traffic paths and security boundaries |
| **Design Sandbox** | Click **Example 1** → compare with **Example 2** → try **Example 3** | Why IAM isn't a network route; what endpoints would change; public SSH risks |
| **Run the Real Lab** | Start with **Step Zero: make doctor**, then Checkpoint 1 | Terminal-based testing, creating and inspecting emulated resources |
| **Incident Cases** | Pick a failure, inspect evidence, make a diagnosis | Engineering reasoning and documented postmortems |

### Design Sandbox = a thought experiment

The switches do **not** modify Terraform configuration or resources. The right panel explains the *hypothetical* outcome. SSM endpoints, NAT and public SSH are **not implemented resources** in this repo. The optional advanced values are educational labels; **never paste them into a Linux shell**.

### Real Lab = run commands yourself

Open a **second terminal in the project root**. For each checkpoint, read its purpose, what it changes and its expected result; copy and run one command, review the terminal output, then optionally paste a non-sensitive excerpt into the page. The browser only matches expected output text; **it does not attest that anything really ran.**

| Step | Command | Prerequisite / effect |
| --- | --- | --- |
| **0. Before anything** | `make doctor` | Read-only. Diagnoses Terraform, Docker, Floci and state |
| **1. Tests** | `make test` | No Docker, AWS account or changes to live resources |
| **2. API emulator** | `make local-up` | Reuses healthy Floci; otherwise starts it using Docker |
| **3. Plan** | `make local-plan` | Shows what Terraform would change; doesn't apply |
| **4. Apply** | `make local-apply` | **Changes local emulator/state** after manual review |
| **5. Verify** | `make local-verify` | Local AWS CLI query of actual emulated resources |
| **6. Drift drill** | `make local-drift` | **Changes local VPC Name tag**, guarded, repairs with consent |
| **7. Optional KVM** | `python3 engineering-lab/probe.py` | Read-only observation of Floci + independent Ubuntu guest |

**If a command says `No changes`**: that is a good result. You already have matching infrastructure; do not repeatedly apply just to score UI checkpoints. If `make doctor` reports a stale VPC/state mismatch, stop and inspect a plan first.

### What happens behind the scenes?

```text
Your browser               Your terminal                  Local emulated API
    |                            |                                  |
Shows architecture       Runs make / Terraform                Floci (localhost)
Explains decisions       Checks plan and local state          Returns VPC / subnets
Never runs commands      You approve changes explicitly      No real AWS resources
```

- **Terraform configuration** says what should exist.
- **Terraform state** remembers what Terraform manages.
- **Terraform plan** compares desired configuration with observed resources.
- **Floci** emulates selected AWS APIs; it does **not** reproduce AWS networking, IAM enforcement, costs or availability.
- **KVM VM** is a separate optional local Ubuntu machine; it is not the emulated EC2 instance.

## Safety and verification

The UI server binds to `127.0.0.1` and serves only `index.html`, `app.js`, `style.css` and `missions.json`; it denies `.git`, Terraform state, scripts and symlink escapes, with restrictive security headers. **Do not serve the repository root with a generic HTTP server.**

Browser simulation never connects to Docker, Terraform, AWS or libvirt. Any pasted command output stays in browser memory; do not paste secrets. The optional `probe.py` runs read-only local queries and returns limited JSON. Do not weaken Docker socket permissions for this lab, or run real-AWS commands as part of the training flow.

Security preflight: `bash engineering-lab/security-preflight.sh`.

Automated checks: `python3 -m unittest discover -s engineering-lab -p 'test_*.py' -v`.

Read the [root README](../README.md) for the architecture, prerequisites and troubleshooting. The deeper [local VM runbook](../docs/LOCAL_VM.md) is optional.
