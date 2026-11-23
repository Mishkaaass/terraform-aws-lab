# Interview demo script (5-8 minutes)

1. Problem: "I wanted a repeatable cloud lab that a reviewer can inspect without giving me AWS credentials."
2. Architecture: show separate roots, reusable modules and the public/private routing diagram.
3. Test: run `make test`, explain a real plan vs a mocked test and why tests don't replace AWS verification.
4. Security: show IMDSv2, EBS encryption, IAM trust vs permissions, no public IP/SSH, zero ingress.
5. Emulator: `make local-up`, `make local-plan`, optional local apply/verify and clean up.
6. CI: show two gates and read-only Actions token; show a failing security assertion on a PR.
7. Tradeoffs: no NAT or interface endpoints, compute disabled by default, Floci not real AWS, S3 remote state and cost controls as next milestones.

Possible questions: How does a Terraform dependency graph work? What is the difference between `plan`, `apply`, `refresh`, `import`, and `state mv`? Why avoid hardcoded credentials? What is drift? How can you recover a corrupt state file? What does an internet gateway *not* provide? What allows SSM management to a private-only instance? Why is `terraform test` with mocks not an integration test?
