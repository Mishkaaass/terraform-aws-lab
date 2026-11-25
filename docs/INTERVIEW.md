# Interview walkthrough — 5–8 minutes

**Goal:** demonstrate an actual IaC workflow without asking an interviewer for AWS credentials or Docker access.

1. **Problem (30s):** “How do we make secure infrastructure understandable, testable and reproducible before using real cloud resources?”
2. **Architecture (60s):** open `make studio`. In **System Map**, follow the VPC, two public and two isolated private subnets across two AZs, the IGW route, SG and IAM/SSM. Explain **IAM permission is not network connectivity**.
3. **Design decisions (60s):** **Design Sandbox** Example 1 then Example 2. Explicitly say it is a browser-only what-if model, not a deployed VPC endpoint.
4. **Automation and security (60s):** `make test` validates HCL using mocked AWS provider; `make doctor` checks the host. Show EC2 disabled by default, no public IP or inbound SG, IMDSv2 and encrypted EBS configuration.
5. **Real API evidence (60s):** `make local-plan`, then **only if already deployed** `make local-verify`. The verifier reads Floci APIs and **fails** on incorrect routing, CIDRs, AZs, public IP assignment, ingress/egress or IAM policy. `No changes` is a good Terraform result; never apply only for visual impact.
6. **Incident response (60s):** show `make local-drift` evidence from a prior local run, or perform the explicitly consented drill in a disposable emulator. Explain Terraform exit codes 0 (no diff) and 2 (diff), a narrowly scoped saved plan and restoration.
7. **CI and limitations (30–60s):** open the five checks: Terraform tests, Floci apply/verify/drift/destroy, static VM checks, Trivy and Gitleaks. No AWS deploy credentials. Floci emulates **APIs**, not real AWS isolation or IAM behavior; SSM endpoints, remote state, real production monitoring and cost controls are out of scope.

## Be ready to explain

- Desired configuration vs state vs observed resources; stale state after an emulator reset.
- Why route-table **associations** matter as much as routes.
- Why subnet placement in two AZs does not by itself prove high availability.
- Why a role with `AmazonSSMManagedInstanceCore` cannot operate without NAT or private interface endpoints.
- Why EC2 is plan-tested, not actually executed by default: no privileged Docker socket mount.
- Which tests are mocks, which independently query Floci, and which real-cloud guarantees remain unverified.
- How to recover from drift safely: back up state, inspect refresh and changes, approve only the expected local diff.
- Why GitHub Actions are pinned to commit SHAs and Floci to a verified immutable multi-platform digest.

**No automatic AWS deployment. No sharing a real cloud account, state file, secrets or live credentials during the demo.**
