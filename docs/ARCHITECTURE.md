# Architecture decision records

## ADR-001: Separate Floci and AWS root modules
**Decision:** two independent Terraform roots reuse the same modules. Local config contains test credentials and local service endpoints; cloud config accepts only real AWS profile credentials and checks the requested account ID. Each root maintains separate local state.
**Tradeoff:** some duplication in `main.tf` prevents an accidental endpoint flip from executing against a production account.

## ADR-002: Two AZ subnet topology; no NAT in starter
One VPC `10.42.0.0/16`. Two public subnets at `10.42.0.0/24` and `10.42.1.0/24`. Two private isolated subnets at `10.42.10.0/24` and `10.42.11.0/24`.
Public route table forwards 0.0.0.0/0 to IGW; private route table has only implicit local routing. VPC DNS is enabled. `map_public_ip_on_launch=false` everywhere.

## ADR-003: Private-only EC2; no inbound traffic
EC2 is **disabled** unless opted in, lives in a private subnet, has no public IPv4 or SSH key, requires IMDSv2, encrypts its root disk, and attaches an SSM agent role. VPC-only HTTPS egress SG is prepared for future private SSM endpoints; without endpoints, instance is isolated and not reachable by SSM.

## ADR-004: Mock tests before live integration
`terraform test` uses a mock AWS provider with plan-only tests so the gate needs neither credentials nor cloud resources. Floci API integration is a distinct local step. Real cloud behavior must be tested separately, with spending and account guardrails.

## ADR-005: Avoid Docker socket in default emulator
Floci supports Docker-backed EC2 execution, but a mounted Docker daemon socket grants powerful host control. Default Compose has no Docker-socket mount; EC2 is tested as Terraform configuration only. A later optional EC2 integration lab may use a dedicated disposable VM and an isolated Docker daemon.
