#!/usr/bin/env bash
set -euo pipefail

mode="${MODE:-run}"
target_repo="${TARGET_REPO:-}"
log_level="${LOG_LEVEL:-info}"
config_file="${CONFIG_FILE:-renovate.json}"
require_config="${REQUIRE_CONFIG:-optional}"
autodiscover="${AUTODISCOVER:-false}"
renovate_author_email="${RENOVATE_AUTHOR_EMAIL:-5534031+redjax@users.noreply.github.com}"
base_branches="${BASE_BRANCHES:-}"
use_base_branch_config="${USE_BASE_BRANCH_CONFIG:-false}"

: "${RENOVATE_TOKEN:?RENOVATE_TOKEN is required}"
: "${GITHUB_COM_TOKEN:?GITHUB_COM_TOKEN is required}"

if [[ -f "app/${config_file}" ]]; then
  selected_config="app/${config_file}"
elif [[ -f "pipelinetemplates/.concourse/maint/renovate/config/default.json" ]]; then
  selected_config="pipelinetemplates/.concourse/maint/renovate/config/default.json"
else
  echo "[ERROR] No renovate config found at 'app/${config_file}' or default template config." >&2
  exit 1
fi

case "${mode}" in
extract)
  dry_run="extract"
  ;;
lookup)
  dry_run="lookup"
  ;;
run)
  dry_run="false"
  ;;
*)
  echo "[ERROR] Invalid mode: ${mode}" >&2
  exit 1
  ;;
esac

export LOG_LEVEL="${log_level}"
export RENOVATE_PLATFORM="github"
export RENOVATE_REQUIRE_CONFIG="${require_config}"
export RENOVATE_AUTODISCOVER="${autodiscover}"

[[ -n "${target_repo}" ]] && export RENOVATE_REPOSITORIES="${target_repo}"

export RENOVATE_DRY_RUN="${dry_run}"
export RENOVATE_CONFIG_FILE="${selected_config}"
export RENOVATE_GIT_AUTHOR="Renovate Bot <${renovate_author_email}>"
export GITHUB_COM_TOKEN="${GITHUB_COM_TOKEN}"
export GITHUB_TOKEN="${GITHUB_COM_TOKEN}"
export RENOVATE_TOKEN="${RENOVATE_TOKEN}"
export RENOVATE_BASE_BRANCHES="${base_branches}"
export RENOVATE_USE_BASE_BRANCH_CONFIG="${use_base_branch_config}"

echo "[INFO] CONFIG: ${selected_config}"
echo "[INFO] MODE: ${mode}"
echo "[INFO] TARGET_REPO: ${target_repo}"

exec renovate
