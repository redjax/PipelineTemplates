#!/usr/bin/env bash
set -euo pipefail

#########################################################
# Run ShellCheck                                        #
#                                                       #
# Environment variables:                                #
#   SHELLCHECK_VERSION                                  #
#   SHELLCHECK_INSTALL_DIR                              #
#   SHELLCHECK_BIN                                      #
#   SHELLCHECK_CONFIG_PATH                              #
#   SHELLCHECK_SCAN_PATH                                #
#   SHELLCHECK_INCLUDE_PATTERNS                         #
#   SHELLCHECK_EXCLUDE_PATHS                            #
#   SHELLCHECK_REPORT_PATH                              #
#   SHELLCHECK_FAIL_ON_FINDINGS                         #
#########################################################

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_REPOSITORY_ROOT="$(cd "${_DIR}/../../../.." && pwd)"

source "${_REPOSITORY_ROOT}/shared/scripts/bash/_util/is-installed.sh"

SHELLCHECK_VERSION="${SHELLCHECK_VERSION:-0.10.0}"
SHELLCHECK_INSTALL_DIR="${SHELLCHECK_INSTALL_DIR:-${HOME}/.local/bin}"
SHELLCHECK_BIN="${SHELLCHECK_BIN:-}"
SHELLCHECK_CONFIG_PATH="${SHELLCHECK_CONFIG_PATH:-}"
SHELLCHECK_SCAN_PATH="${SHELLCHECK_SCAN_PATH:-.}"
SHELLCHECK_INCLUDE_PATTERNS="${SHELLCHECK_INCLUDE_PATTERNS:-*.sh,*.bash,*.bats}"
SHELLCHECK_EXCLUDE_PATHS="${SHELLCHECK_EXCLUDE_PATHS:-.git,node_modules,vendor,dist,build,.terraform}"
SHELLCHECK_REPORT_PATH="${SHELLCHECK_REPORT_PATH:-./reports/shellcheck/shellcheck.txt}"
SHELLCHECK_FAIL_ON_FINDINGS="${SHELLCHECK_FAIL_ON_FINDINGS:-false}"
SHELLCHECK_STAGED_CONFIG_PATH=""
SHELLCHECK_STAGED_CONFIG_BACKUP=""
SHELLCHECK_STAGED_CONFIG_CREATED=false

function fail() {
  echo "[ERROR] $*" >&2
  exit 2
}

function validate_boolean() {
  local variable_name="${1}"
  local value="${2}"

  case "${value}" in
  true | false) ;;
  *)
    fail "${variable_name} must be either 'true' or 'false'."
    ;;
  esac
}

function validate_inputs() {
  validate_boolean "SHELLCHECK_FAIL_ON_FINDINGS" "${SHELLCHECK_FAIL_ON_FINDINGS}"

  if [[ ! -e "${SHELLCHECK_SCAN_PATH}" ]]; then
    fail "SHELLCHECK_SCAN_PATH does not exist: ${SHELLCHECK_SCAN_PATH}"
  fi

  if [[ -n "${SHELLCHECK_CONFIG_PATH}" && ! -f "${SHELLCHECK_CONFIG_PATH}" ]]; then
    fail "SHELLCHECK_CONFIG_PATH does not exist: ${SHELLCHECK_CONFIG_PATH}"
  fi
}

function resolve_shellcheck_binary() {
  if [[ -n "${SHELLCHECK_BIN}" ]]; then
    [[ -x "${SHELLCHECK_BIN}" ]] || fail "SHELLCHECK_BIN is not executable: ${SHELLCHECK_BIN}"
    return 0
  fi

  if [[ -x "${SHELLCHECK_INSTALL_DIR}/shellcheck" ]]; then
    SHELLCHECK_BIN="${SHELLCHECK_INSTALL_DIR}/shellcheck"
    return 0
  fi

  if is_installed shellcheck; then
    SHELLCHECK_BIN="$(command -v shellcheck)"
    return 0
  fi

  echo "[INFO] ShellCheck is not installed; installing v${SHELLCHECK_VERSION}"

  SHELLCHECK_VERSION="${SHELLCHECK_VERSION}" \
    SHELLCHECK_INSTALL_DIR="${SHELLCHECK_INSTALL_DIR}" \
    bash "${_REPOSITORY_ROOT}/shared/scripts/bash/installers/install-shellcheck.sh"

  SHELLCHECK_BIN="${SHELLCHECK_INSTALL_DIR}/shellcheck"
}

function get_shellcheck_config_directory() {
  if [[ -d "${SHELLCHECK_SCAN_PATH}" ]]; then
    (
      cd "${SHELLCHECK_SCAN_PATH}"
      pwd
    )

    return 0
  fi

  (
    cd "$(dirname "${SHELLCHECK_SCAN_PATH}")"
    pwd
  )
}

function stage_shellcheck_config() {
  local config_directory=""
  local staged_config_path=""

  if [[ -z "${SHELLCHECK_CONFIG_PATH}" ]]; then
    return 0
  fi

  config_directory="$(get_shellcheck_config_directory)"
  staged_config_path="${config_directory}/.shellcheckrc"

  if [[ "${SHELLCHECK_CONFIG_PATH}" == "${staged_config_path}" ]]; then
    echo "[INFO] ShellCheck configuration already exists in the scan root."
    return 0
  fi

  SHELLCHECK_STAGED_CONFIG_PATH="${staged_config_path}"

  if [[ -f "${staged_config_path}" ]]; then
    SHELLCHECK_STAGED_CONFIG_BACKUP="$(mktemp)"

    cp \
      "${staged_config_path}" \
      "${SHELLCHECK_STAGED_CONFIG_BACKUP}"
  else
    SHELLCHECK_STAGED_CONFIG_CREATED=true
  fi

  cp \
    "${SHELLCHECK_CONFIG_PATH}" \
    "${staged_config_path}"

  echo "[INFO] Staged ShellCheck configuration in scan root."
}

function restore_shellcheck_config() {
  if [[ -z "${SHELLCHECK_STAGED_CONFIG_PATH:-}" ]]; then
    return 0
  fi

  if [[ -n "${SHELLCHECK_STAGED_CONFIG_BACKUP:-}" ]]; then
    cp \
      "${SHELLCHECK_STAGED_CONFIG_BACKUP}" \
      "${SHELLCHECK_STAGED_CONFIG_PATH}"

    rm --force "${SHELLCHECK_STAGED_CONFIG_BACKUP}"

    return 0
  fi

  if [[ "${SHELLCHECK_STAGED_CONFIG_CREATED:-false}" == "true" ]]; then
    rm --force "${SHELLCHECK_STAGED_CONFIG_PATH}"
  fi
}

function path_is_excluded() {
  local file_path="${1}"
  local excluded_path
  local -a excluded_paths=()

  IFS=',' read -r -a excluded_paths <<<"${SHELLCHECK_EXCLUDE_PATHS}"

  for excluded_path in "${excluded_paths[@]}"; do
    excluded_path="${excluded_path#"${excluded_path%%[![:space:]]*}"}"
    excluded_path="${excluded_path%"${excluded_path##*[![:space:]]}"}"

    if [[ -z "${excluded_path}" ]]; then
      continue
    fi

    if [[ "${file_path}" == *"/${excluded_path}/"* || "${file_path}" == *"/${excluded_path}" ]]; then
      return 0
    fi
  done

  return 1
}

function find_shell_files() {
  local include_pattern
  local file_path
  local -a include_patterns=()

  IFS=',' read -r -a include_patterns <<<"${SHELLCHECK_INCLUDE_PATTERNS}"

  while IFS= read -r -d '' file_path; do
    if path_is_excluded "${file_path}"; then
      continue
    fi

    for include_pattern in "${include_patterns[@]}"; do
      include_pattern="${include_pattern#"${include_pattern%%[![:space:]]*}"}"
      include_pattern="${include_pattern%"${include_pattern##*[![:space:]]}"}"

      # shellcheck disable=SC2053
      # include_pattern is intentionally a glob, for example: *.sh or *.bash.
      if [[ -n "${include_pattern}" && "$(basename "${file_path}")" == ${include_pattern} ]]; then
        printf '%s\0' "${file_path}"
        break
      fi
    done
  done < <(
    find "${SHELLCHECK_SCAN_PATH}" \
      -type f \
      -print0
  )
}

function main() {
  local shellcheck_exit_code=0
  local finding_count=0
  local has_findings=false
  local -a command=()
  local -a shell_files=()

  validate_inputs
  resolve_shellcheck_binary

  trap restore_shellcheck_config EXIT
  stage_shellcheck_config

  mkdir --parents "$(dirname "${SHELLCHECK_REPORT_PATH}")"

  while IFS= read -r -d '' file_path; do
    shell_files+=("${file_path}")
  done < <(find_shell_files)

  if [[ "${#shell_files[@]}" -eq 0 ]]; then
    : >"${SHELLCHECK_REPORT_PATH}"

    echo "[INFO] No files matched SHELLCHECK_INCLUDE_PATTERNS."
    echo "SHELLCHECK_FINDING_COUNT=0"
    echo "SHELLCHECK_HAS_FINDINGS=false"
    echo "SHELLCHECK_REPORT_PATH=${SHELLCHECK_REPORT_PATH}"

    return 0
  fi

  command=(
    "${SHELLCHECK_BIN}"
    --format gcc
    "${shell_files[@]}"
  )

  echo "[INFO] Running ShellCheck against ${#shell_files[@]} file(s)."

  set +e
  "${command[@]}" >"${SHELLCHECK_REPORT_PATH}"
  shellcheck_exit_code=$?
  set -e

  case "${shellcheck_exit_code}" in
  0) ;;
  1) ;;
  *)
    cat "${SHELLCHECK_REPORT_PATH}" >&2
    fail "ShellCheck failed with exit code ${shellcheck_exit_code}."
    ;;
  esac

  finding_count="$(
    grep \
      --extended-regexp \
      --count \
      'SC[0-9]+' \
      "${SHELLCHECK_REPORT_PATH}" ||
      true
  )"

  if [[ "${finding_count}" -gt 0 ]]; then
    has_findings=true
    echo "[WARN] ShellCheck reported ${finding_count} finding(s)."
  else
    echo "[INFO] ShellCheck completed with no findings."
  fi

  echo "SHELLCHECK_FINDING_COUNT=${finding_count}"
  echo "SHELLCHECK_HAS_FINDINGS=${has_findings}"
  echo "SHELLCHECK_REPORT_PATH=${SHELLCHECK_REPORT_PATH}"

  if [[ "${SHELLCHECK_FAIL_ON_FINDINGS}" == "true" && "${has_findings}" == "true" ]]; then
    exit 1
  fi
}

main "$@"
