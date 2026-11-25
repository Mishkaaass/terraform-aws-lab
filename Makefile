.DEFAULT_GOAL := help
SHELL := /bin/bash
TF := bash scripts/terraform.sh
.PHONY: help requirements setup studio studio-docker publish-release doctor check fmt fmt-check init-local init-aws validate test local-up local-plan local-apply local-verify local-drift local-destroy local-down local-ec2-plan aws-plan aws-apply aws-destroy

help:
	@printf '%s\n' 'START HERE:' '  make requirements     - check prerequisites without changing anything' '  make setup            - create/reuse .venv (no external Python packages)' '  make studio           - automatically use .venv for browser Studio' '  make studio-docker    - alternate isolated browser-only container (Docker needed)' '  make doctor           - check tools and local state (read-only)' '  make test             - Terraform mock tests (no Docker or AWS)' '' 'LOCAL FLOCI (OPTIONAL):' '  make local-up         - reuse existing emulator, or start with Docker' '  make local-plan       - inspect proposed changes' '  make local-apply      - changes emulator/state; asks approval' '  make local-verify     - inspect the local AWS API' '  make local-drift      - local out-of-band tag change and repair drill' '' 'MORE:' '  make check            - toolchain and security checks' '  make fmt-check        - verify Terraform formatting' '  make validate         - validate Terraform roots' '  make local-down       - stop emulator; no volume deletion' '  make local-destroy    - destructive emulator cleanup, interactive' '  make aws-plan         - only after AWS sandbox safeguards' '  make publish-release  - GitHub v1.0.0 release (requires 6 green checks and explicit consent)' '' 'Run make help to see this list again.'

requirements:
	@bash scripts/requirements.sh

setup:
	@bash scripts/setup-studio.sh

studio: setup
	@.venv/bin/python engineering-lab/serve.py

studio-docker:
	@docker compose --profile studio up --build studio

doctor:
	@bash engineering-lab/doctor.sh

check:
	@bash scripts/check.sh

fmt:
	@$(TF) fmt -recursive

fmt-check:
	@$(TF) fmt -check -recursive

init-local:
	@$(TF) -chdir=environments/floci init -input=false

init-aws:
	@$(TF) -chdir=environments/aws init -backend=false -input=false

validate: init-local init-aws
	@$(TF) -chdir=environments/floci validate
	@$(TF) -chdir=environments/aws validate

test: init-local
	@$(TF) -chdir=environments/floci test -no-color

local-up:
	@# If the existing localhost emulator is healthy, do not require Docker daemon access.
	@if curl --noproxy '*' -fsS --max-time 2 http://127.0.0.1:4566/_floci/health >/dev/null 2>&1; then \
		echo '[REUSE] Healthy localhost Floci found; skipping Docker startup.'; \
	else \
		echo '[INFO] Local Floci is not running; Docker access is required to start it.'; \
		if ! docker info >/dev/null 2>&1; then \
			echo '[BLOCK] Docker daemon unavailable to this user. Do not change socket permissions.' >&2; \
			echo '[INFO] Use an isolated lab host or review your Docker setup first.' >&2; \
			exit 1; \
		fi; \
		docker compose up -d || exit $?; \
	fi
	@bash scripts/wait-floci.sh

local-plan: local-up init-local
	@$(TF) -chdir=environments/floci plan

local-apply: local-up init-local
	@$(TF) -chdir=environments/floci apply

local-verify:
	@bash scripts/verify-local.sh

local-drift:
	@bash scripts/drift-lab.sh

local-destroy: init-local
	@echo 'CAUTION: local Terraform resources will be deleted after your confirmation.'
	@$(TF) -chdir=environments/floci destroy

local-down:
	@docker compose down

local-ec2-plan: local-up init-local
	@echo 'EC2 plan only. Floci EC2 requires Docker socket to actually execute a guest.'
	@$(TF) -chdir=environments/floci plan -var='enable_compute=true'

aws-plan:
	@bash scripts/aws-command.sh plan

aws-apply:
	@bash scripts/aws-command.sh apply

aws-destroy:
	@bash scripts/aws-command.sh destroy

publish-release:
	@bash scripts/publish-release.sh
