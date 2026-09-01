#!/usr/bin/env bash
set -euo pipefail

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_REPOSITORY_ROOT="$(cd "${_DIR}/../../../.." && pwd)"

source "${_REPOSITORY_ROOT}/shared/scripts/bash/_util/is-installed.sh"

SHELLCHECK_VERSION="${SHELLCHECK_VERSION:-0.10.0}"
SHELLCHECK_SEVERITY="${SHELLCHECK_SEVERITY:-error}"
SHELLCHECK_INSTALL_DIR="${SHELLCHECK_INSTALL_DIR:-${HOME}/.local/bin}"
SHELLCHECK_BIN="${SHELLCHECK_BIN:-}"
SHELLCHECK_CONFIG_PATH="${SHELLCHECK_CONFIG_PATH:-}"
SHELLCHECK_SCAN_PATH="${SHELLCHECK_SCAN_PATH:-.}"
SHELLCHECK_INCLUDE_PATTERNS="${SHELLCHECK_INCLUDE_PATTERNS:-*.sh,*.bash,*.bats}"
SHELLCHECK_EXCLUDE_PATHS="${SHELLCHECK_EXCLUDE_PATHS:-.git,node_modules,vendor,dist,build,.terraform}"
SHELLCHECK_REPORT_PATH="${SHELLCHECK_REPORT_PATH:-./reports/shellcheck/shellcheck.txt}"
SHELLCHECK_FAIL_ON_FINDINGS="${SHELLCHECK_FAIL_ON_FINDINGS:-true}"

SHELLCHECK_STAGED_CONFIG_PATH=""
SHELLCHECK_STAGED_CONFIG_BACKUP=""
SHELLCHECK_STAGED_CONFIG_CREATED=false

function fail() {
  echo "[ERROR] $*" >&2
  exit 2
}

function validate_inputs() {
  case "${SHELLCHECK_FAIL_ON_FINDINGS}" in
  true | false) ;;
  *)
    fail "SHELLCHECK_FAIL_ON_FINDINGS must be true or false."
    ;;
  esac

  [[ -e "${SHELLCHECK_SCAN_PATH}" ]] ||
    fail "SHELLCHECK_SCAN_PATH does not exist: ${SHELLCHECK_SCAN_PATH}"

  if [[ -n "${SHELLCHECK_CONFIG_PATH}" ]]; then
    [[ -f "${SHELLCHECK_CONFIG_PATH}" ]] ||
      fail "SHELLCHECK_CONFIG_PATH does not exist: ${SHELLCHECK_CONFIG_PATH}"
  fi
}

function resolve_shellcheck_binary() {
  if [[ -n "${SHELLCHECK_BIN}" ]]; then
    [[ -x "${SHELLCHECK_BIN}" ]] ||
      fail "SHELLCHECK_BIN is not executable: ${SHELLCHECK_BIN}"

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

  SHELLCHECK_VERSION="${SHELLCHECK_VERSION}" \
    SHELLCHECK_INSTALL_DIR="${SHELLCHECK_INSTALL_DIR}" \
    bash "${_REPOSITORY_ROOT}/shared/scripts/bash/installers/install-shellcheck.sh"

  SHELLCHECK_BIN="${SHELLCHECK_INSTALL_DIR}/shellcheck"
}

function get_config_directory() {
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

function stage_config() {
  local config_directory
  local target_path

  [[ -n "${SHELLCHECK_CONFIG_PATH}" ]] || return 0

  config_directory="$(get_config_directory)"
  target_path="${config_directory}/.shellcheckrc"

  if [[ "${SHELLCHECK_CONFIG_PATH}" == "${target_path}" ]]; then
    return 0
  fi

  SHELLCHECK_STAGED_CONFIG_PATH="${target_path}"

  if [[ -f "${target_path}" ]]; then
    SHELLCHECK_STAGED_CONFIG_BACKUP="$(mktemp)"
    cp "${target_path}" "${SHELLCHECK_STAGED_CONFIG_BACKUP}"
  else
    SHELLCHECK_STAGED_CONFIG_CREATED=true
  fi

  cp "${SHELLCHECK_CONFIG_PATH}" "${target_path}"
}

function restore_config() {
  [[ -n "${SHELLCHECK_STAGED_CONFIG_PATH:-}" ]] || return 0

  if [[ -n "${SHELLCHECK_STAGED_CONFIG_BACKUP:-}" ]]; then
    cp \
      "${SHELLCHECK_STAGED_CONFIG_BACKUP}" \
      "${SHELLCHECK_STAGED_CONFIG_PATH}"

    rm --force "${SHELLCHECK_STAGED_CONFIG_BACKUP}"
    return 0
  fi

  if [[ "${SHELLCHECK_STAGED_CONFIG_CREATED}" == "true" ]]; then
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

    [[ -n "${excluded_path}" ]] || continue

    if [[ "${file_path}" == *"/${excluded_path}/"* || "${file_path}" == *"/${excluded_path}" ]]; then
      return 0
    fi
  done

  return 1
}

function find_shell_files() {
  local file_path
  local include_pattern
  local -a include_patterns=()

  IFS=',' read -r -a include_patterns <<<"${SHELLCHECK_INCLUDE_PATTERNS}"

  while IFS= read -r -d '' file_path; do
    path_is_excluded "${file_path}" && continue

    for include_pattern in "${include_patterns[@]}"; do
      include_pattern="${include_pattern#"${include_pattern%%[![:space:]]*}"}"
      include_pattern="${include_pattern%"${include_pattern##*[![:space:]]}"}"

      # shellcheck disable=SC2053
      if [[ -n "${include_pattern}" && "$(basename "${file_path}")" == ${include_pattern} ]]; then
        printf '%s\0' "${file_path}"
        break
      fi
    done
  done < <(find "${SHELLCHECK_SCAN_PATH}" -type f -print0)
}

function main() {
  local exit_code=0
  local -a shell_files=()
  local -a command=()

  validate_inputs
  resolve_shellcheck_binary

  trap restore_config EXIT
  stage_config

  mkdir --parents "$(dirname "${SHELLCHECK_REPORT_PATH}")"

  while IFS= read -r -d '' file_path; do
    shell_files+=("${file_path}")
  done < <(find_shell_files)

  if [[ "${#shell_files[@]}" -eq 0 ]]; then
    : >"${SHELLCHECK_REPORT_PATH}"
    echo "[INFO] No ShellCheck files found."
    exit 0
  fi

  command=(
    "${SHELLCHECK_BIN}"
    --format gcc
    "--severity=${SHELLCHECK_SEVERITY}"
    --external-sources
  )

  command+=("${shell_files[@]}")

  printf '[INFO] Command:'
  printf ' %q' "${command[@]}"
  printf '\n'

  set +e
  "${command[@]}" >"${SHELLCHECK_REPORT_PATH}" 2>&1
  exit_code=$?
  set -e

  case "${exit_code}" in
  0)
    echo "[INFO] ShellCheck completed with no findings."
    ;;
  1)
    echo "[WARN] ShellCheck found lint findings."
    ;;
  *)
    cat "${SHELLCHECK_REPORT_PATH}" >&2
    echo "[ERROR] ShellCheck failed with exit code ${exit_code}." >&2
    exit "${exit_code}"
    ;;
  esac

  if [[ "${SHELLCHECK_FAIL_ON_FINDINGS}" == "true" && "${exit_code}" == "1" ]]; then
    exit 1
  fi
}

main "$@"
