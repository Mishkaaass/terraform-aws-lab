# Infrastructure Studio — guided reviewer playground

This is a **working learning lab**, not a screenshot or just multiple-choice questions. The experience is deliberately different from the CI/CD OpsBoard UI: a light architectural drawing board, interactive component inspector, design what-if controls, seven genuine terminal checkpoints and separate real-incident review.

## Start the safe browser mode

Requirements: Python 3 and a browser. **No AWS account, Docker, Terraform, sudo, libvirt or credentials needed.**

From the repository root:

```bash
python3 engineering-lab/serve.py
```

Open http://127.0.0.1:8765/ (localhost only); stop with Ctrl+C.

The dedicated local server **only serves `index.html`, `app.js`, `style.css`, and `missions.json`**. It enforces an exact path allowlist, rejects symlinked assets, Host/Origin mismatches, and sends CSP, anti-frame, no-sniff and no-cache headers. Never use `python3 -m http.server` from the repository root: Terraform state and Git metadata must remain private.

## Four workspaces

### 01 — System Map: see the real architecture

Click any node to see what Terraform declares, its value, the exact source module and the implication of that choice. The VPC is `10.42.0.0/16`; the Floci subnets are `10.42.0.0/24`, `10.42.1.0/24`, `10.42.10.0/24`, `10.42.11.0/24`. Public route tables point to the IGW; private route tables have no default route. The instance security group has **zero ingress** and only intra-VPC TCP 443 egress. The instance IAM profile has the SSM agent policy, but compute is disabled by default.

**Try:** Click the private subnet, then the security group, then the IAM profile. Explain why 'private', 'authorized to use SSM' and 'able to reach SSM' are three separate properties.

## A first-time reviewer's 5-minute route

**No experience required to start:** Open the studio and follow the tabs left to right.

**Design Sandbox (simulation; no changes):** The top of the page explains four actions. Click **Example 1: Why can't my EC2 use SSM?**; the switches will be set automatically. Read the explanation under the examples and the right-hand diagnosis. Then click **Example 2: Manage EC2 privately** and explain why the proposed endpoints help, but still need DNS, security-group and real connectivity verification. Click **Example 3: What if I open SSH?** to inspect the security warning. You can adjust the toggles yourself afterward. None of those hypothetical SSM/NAT/SSH additions exists as a real Terraform implementation.

**Run the Real Lab (terminal companion):** Read the four-step explanation: open a terminal in the cloned repo, copy just the command for the current checkpoint, run it manually, inspect its output, then paste *non-sensitive* output and click **Check Output Text**. Start at checkpoint 1 (`make test`), which does not need Docker or AWS. To go further, checkpoints 2–6 need a local emulator/Docker, and some need the AWS CLI. **Apply and drift modify the local emulator and Terraform state; explicitly review and approve them.** Checkpoint 7 is optional. The pasted-output matcher only detects expected strings; it is **not** secure proof of execution or a replacement for human review.

**Different purposes:** Design Sandbox helps you *predict*. Run the Real Lab helps you *observe*. Incident Cases checks whether you can *diagnose*.

### 02 — Design Sandbox: explore changes before making them

Change toggles for private EC2, *proposed/not-yet-implemented* SSM interface endpoints, hypothetical NAT, public IP, and worldwide SSH ingress. The what-if analysis updates immediately and explains the missing routes, policy clashes and security risks.

**Important:** The change list is **a browser teaching model, not `terraform plan` output**. Changes are not written to `.tf` files or deployed to the emulator. Some toggles intentionally describe architectural alternatives that the repo does not implement.

**Try:** Enable EC2 alone. Why is the IAM SSM policy insufficient? Add the proposed endpoints. Which endpoint SG/DNS tests would be required? Add NAT only. Why does VPC-only HTTPS egress still prevent Internet HTTPS?

### 03 — Run the Real Lab: make Terraform observable

This tab is your guided terminal companion. Every checkpoint has a reviewed command, its effect, expected evidence, a field to paste command output and a basic marker matcher. **The reviewer has to run commands themselves**. Pasted output is kept in page memory, not sent anywhere. Markers are educational convenience checks, **not cryptographic evidence or a substitute for verifying the plan**.

| Stage | Command | Changes anything? | What to observe |
| --- | --- | --- | --- |
| 1. Configuration | `make test` | No cloud/Docker; may initialize local providers | Mock test assertions pass |
| 2. Emulator | `make local-up` | Starts local Floci container | API `127.0.0.1:4566` responds |
| 3. Review | `make local-plan` | Refreshes local state, no resource apply | Inspect add/change/destroy counts |
| 4. Local apply | `make local-apply` | **Yes — emulated AWS and local state**; confirmation required | Terraform apply complete |
| 5. Independent evidence | `make local-verify` | Read-only local AWS API queries | VPC/subnets/SG observed |
| 6. Drift | `make local-drift` | **Yes — local VPC Name tag**, then guarded interactive repair | Strict one-tag plan, final zero drift |
| 7. Optional KVM | `python3 engineering-lab/probe.py` | No — read-only host observations | VM boot, Floci and guest HTTP status |

The default emulator intentionally omits a privileged Docker socket mount, and does not deploy EC2. You should never add one just for the reviewer experience.

#### Read-only host observation

On the same Linux machine where the emulator/VM may be running:

```bash
python3 engineering-lab/probe.py
```

Example **schema only** (values are illustrative, never live in this file):

```json
{
  "schema": 1,
  "source": "local-readonly-probe",
  "observed_at": "2026-11-25T08:00:00+00:00",
  "floci": "up",
  "vm": "running",
  "health": "healthy",
  "vm_ip": "192.168.122.230"
}
```

The probe checks only local Floci health at `127.0.0.1:4566`, `virsh` domain state for `tfaws-lab01`, an unambiguous IPv4 lease on the default `192.168.122.0/24` libvirt NAT subnet, and HTTP `/health` on the discovered guest. It neither SSHes nor uses credentials, AWS CLI, Docker, Terraform or sudo, and reports only fixed fields. In an environment with multiple leases, it refuses to guess the guest's address.

**Security boundary:** This is a *read-only local observation tool*, not an attestation system and not a proof that an API from another machine is the intended VM. The browser only processes JSON that the reviewer explicitly pastes. It does not inspect or contact the host automatically.

### 04 — Incident Cases: demonstrate debugging judgment

Seven real-incident replays and source-based design exercises, with three decisions each (21 in total):

- Running KVM without a visible root disk: guest console → VirtIO PCI diagnostics → host-specific narrow remedy
- AppArmor blocks QEMU backing storage and seed ISO
- Terraform drift outside state and constrained repair
- Emulator/CI evidence vs actual AWS guarantees
- Missing network path to private SSM services
- Ubuntu boot → cloud-init → systemd → host-to-guest HTTP evidence
- Terraform formatting gate fails even though VM runtime works

Review each decision and then write your own postmortem before copying your notes. Reviewers are supposed to explain what they would *observe next*, not just get 21/21 points.

## A genuinely useful 10-minute interview walkthrough

1. **Architecture (2m):** Click private subnet, SG, IAM. Explain CIDR, routing, authorization and connection.
2. **What-if (2m):** Enable EC2 with no endpoints; articulate why SSM cannot connect; test public SSH and reject the proposed exposure.
3. **Real evidence (4m):** Run local tests, emulator/API queries if available, or a read-only VM probe. Explain every shell command and what each output does *not* establish.
4. **Fault review (2m):** Open the missing `/dev/vda` incident and justify the debugging order with evidence.

If your reviewer does not have Docker or KVM, steps 1, 2 and 4 still work fully offline; the real-command workspace is optional and clearly separated.

## Safety, testing and scope

- The browser has no execution endpoint, uses no Docker socket and no AWS credentials. It only fetches the bundled `missions.json`.
- Keep the local UI bound to `127.0.0.1`. The backend serves an exact static allowlist, not the repository root.
- Do not run the real AWS guard/plan/apply from the demo UI. Those operations are deliberately excluded.
- Real lab commands may modify *only the user's local emulator and state* as documented. They are never triggered automatically.
- For a conservative safety check: `bash engineering-lab/security-preflight.sh`.
- Tests: `python3 -m unittest discover -s engineering-lab -p 'test_*.py' -v`.
- CI ensures source/fixture contracts and local HTTP security regressions, but **does not prove actual KVM guest boot on a reviewer machine**.
- The original source-level risk report lives at [SECURITY_AUDIT_2026-11-24.md](../docs/SECURITY_AUDIT_2026-11-24.md).

**Completion is not a green GitHub badge alone:** have at least one reviewer launch the workbench, understand the architecture, run a terminal checkpoint in a disposable emulator, identify a broken design, explain it, and observe why the correct mitigation would work.
