#!/usr/bin/env bash
set -euo pipefail

mode="${mode:-run}"
target_repo="${target_repo:-}"
log_level="${log_level:-info}"
config_file="${config_file:-renovate.json}"
require_config="${require_config:-optional}"
autodiscover="${autodiscover:-false}"
renovate_author_email="${renovate_author_email:-5534031+redjax@users.noreply.github.com}"
base_branches="${base_branches:-}"
use_base_branch_config="${use_base_branch_config:-false}"

: "${renovate_token:?renovate_token is required}"
: "${github_api_token:?github_api_token is required}"

if [[ -f "app/${config_file}" ]]; then
  selected_config="app/${config_file}"
elif [[ -f "app/pipelinetemplates/config/renovate/default.json" ]]; then
  selected_config="app/pipelinetemplates/config/renovate/default.json"
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
export RENOVATE_REPOSITORIES="${target_repo}"
export RENOVATE_DRY_RUN="${dry_run}"
export RENOVATE_CONFIG_FILE="${selected_config}"
export RENOVATE_GIT_AUTHOR="Renovate Bot <${renovate_author_email}>"
export GITHUB_COM_TOKEN="${github_api_token}"
export RENOVATE_BASE_BRANCHES="${base_branches}"
export RENOVATE_USE_BASE_BRANCH_CONFIG="${use_base_branch_config}"

exec /opt/renovate/entrypoint.sh "${renovate_token}"
