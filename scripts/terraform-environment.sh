#!/usr/bin/env bash
# Sourced by the guided CLI entrypoints, not by Terraform itself.
# Refuse inherited flags that can bypass confirmation or redirect state/providers.
lab_check_terraform_environment() {
  local name
  for name in ${!TF_CLI_ARGS@} TF_DATA_DIR TF_WORKSPACE TF_REATTACH_PROVIDERS TF_CLI_CONFIG_FILE TF_LOG TF_LOG_PATH; do
    if [[ -n "${!name:-}" ]]; then
      printf '[BLOCK] Unset %s before using the guided lab commands.\n' "$name" >&2
      return 2
    fi
  done
}
