.DEFAULT_GOAL := help
SHELL := /bin/bash
.PHONY: help check fmt fmt-check init-local init-aws validate test local-up local-plan local-apply local-verify local-drift local-destroy local-down local-ec2-plan aws-plan aws-apply aws-destroy

help:
	@printf '%s\n' 'terraform-aws-lab commands:' '  make check             - prerequisites + static project checks' '  make fmt               - format Terraform files' '  make fmt-check         - check Terraform formatting (read-only)' '  make validate          - init (no backend) + validate both roots' '  make test              - offline mock-provider Terraform tests (no AWS, no Docker)' '  make local-up          - start Floci (no Docker socket)' '  make local-plan        - read-only plan against local Floci' '  make local-apply       - apply local emulated network/IAM, confirm interactively' '  make local-verify      - verify state using local AWS API (requires aws CLI)' '  make local-drift       - simulate, detect and safely repair local tag drift' '  make local-destroy     - interactive destruction of local Terraform resources' '  make local-down        - stop Floci (does not remove Docker volumes)' '  make local-ec2-plan    - mock-free local EC2 plan, NOT apply (no Docker socket)' '  make aws-plan          - real AWS plan after account-ID guard' '  make aws-apply         - guarded, interactive real AWS apply' '  make aws-destroy       - doubly guarded, interactive real AWS destroy'

check:
	@bash scripts/check.sh

fmt:
	@terraform fmt -recursive

fmt-check:
	@terraform fmt -check -recursive

init-local:
	@terraform -chdir=environments/floci init -input=false

init-aws:
	@terraform -chdir=environments/aws init -backend=false -input=false

validate: init-local init-aws
	@terraform -chdir=environments/floci validate
	@terraform -chdir=environments/aws validate

test: init-local
	@terraform -chdir=environments/floci test -no-color

local-up:
	@docker compose up -d
	@bash scripts/wait-floci.sh

local-plan: local-up init-local
	@terraform -chdir=environments/floci plan

local-apply: local-up init-local
	@terraform -chdir=environments/floci apply

local-verify:
	@bash scripts/verify-local.sh

local-drift:
	@bash scripts/drift-lab.sh

local-destroy: init-local
	@echo 'CAUTION: local Terraform resources will be deleted after your confirmation.'
	@terraform -chdir=environments/floci destroy

local-down:
	@docker compose down

local-ec2-plan: local-up init-local
	@echo 'EC2 plan only. Floci EC2 requires Docker socket to actually execute a guest.'
	@terraform -chdir=environments/floci plan -var='enable_compute=true'

aws-plan:
	@bash scripts/aws-command.sh plan

aws-apply:
	@bash scripts/aws-command.sh apply

aws-destroy:
	@bash scripts/aws-command.sh destroy
