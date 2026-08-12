#!/usr/bin/env bash
set -euo pipefail

#########################################################
# Run shellfmt                                          #
#                                                       #
# Environment:                                          #
#   SHELLFMT_VERSION                                    #
#   SHELLFMT_INSTALL_DIR                                #
#   SHELLFMT_BIN                                        #
#   SHELLFMT_CONFIG_PATH                                #
#   SHELLFMT_SCAN_PATH                                  #
#   SHELLFMT_INCLUDE_PATTERNS                           #
#   SHELLFMT_EXCLUDE_PATHS                              #
#   SHELLFMT_REPORT_PATH                                #
#   SHELLFMT_FAIL_ON_FINDINGS                           #
#########################################################

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_REPOSITORY_ROOT="$(cd "${_DIR}/../../../.." && pwd)"

source "${_REPOSITORY_ROOT}/shared/scripts/bash/_util/is-installed.sh"

SHELLFMT_VERSION="${SHELLFMT_VERSION:-3.10.0}"
SHELLFMT_INSTALL_DIR="${SHELLFMT_INSTALL_DIR:-${HOME}/.local/bin}"
SHELLFMT_BIN="${SHELLFMT_BIN:-}"
SHELLFMT_CONFIG_PATH="${SHELLFMT_CONFIG_PATH:-}"
SHELLFMT_SCAN_PATH="${SHELLFMT_SCAN_PATH:-.}"
SHELLFMT_INCLUDE_PATTERNS="${SHELLFMT_INCLUDE_PATTERNS:-*.sh,*.bash,*.bats}"
SHELLFMT_EXCLUDE_PATHS="${SHELLFMT_EXCLUDE_PATHS:-.git,node_modules,vendor,dist,build,.terraform}"
SHELLFMT_REPORT_PATH="${SHELLFMT_REPORT_PATH:-./reports/shellfmt/shellfmt.diff}"
SHELLFMT_FAIL_ON_FINDINGS="${SHELLFMT_FAIL_ON_FINDINGS:-false}"

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
  validate_boolean "SHELLFMT_FAIL_ON_FINDINGS" "${SHELLFMT_FAIL_ON_FINDINGS}"

  if [[ ! -e "${SHELLFMT_SCAN_PATH}" ]]; then
    fail "SHELLFMT_SCAN_PATH does not exist: ${SHELLFMT_SCAN_PATH}"
  fi

  if [[ -n "${SHELLFMT_CONFIG_PATH}" && ! -f "${SHELLFMT_CONFIG_PATH}" ]]; then
    fail "SHELLFMT_CONFIG_PATH does not exist: ${SHELLFMT_CONFIG_PATH}"
  fi
}

function resolve_shellfmt_binary() {
  if [[ -n "${SHELLFMT_BIN}" ]]; then
    [[ -x "${SHELLFMT_BIN}" ]] || fail "SHELLFMT_BIN is not executable: ${SHELLFMT_BIN}"
    return 0
  fi

  if [[ -x "${SHELLFMT_INSTALL_DIR}/shfmt" ]]; then
    SHELLFMT_BIN="${SHELLFMT_INSTALL_DIR}/shfmt"
    return 0
  fi

  if is_installed shfmt; then
    SHELLFMT_BIN="$(command -v shfmt)"
    return 0
  fi

  echo "[INFO] shellfmt is not installed; installing v${SHELLFMT_VERSION}"

  SHELLFMT_VERSION="${SHELLFMT_VERSION}" \
    SHELLFMT_INSTALL_DIR="${SHELLFMT_INSTALL_DIR}" \
    bash "${_REPOSITORY_ROOT}/shared/scripts/bash/installers/install-shellfmt.sh"

  SHELLFMT_BIN="${SHELLFMT_INSTALL_DIR}/shfmt"
}

function path_is_excluded() {
  local file_path="${1}"
  local excluded_path
  local -a excluded_paths=()

  IFS=',' read -r -a excluded_paths <<<"${SHELLFMT_EXCLUDE_PATHS}"

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

  IFS=',' read -r -a include_patterns <<<"${SHELLFMT_INCLUDE_PATTERNS}"

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
    find "${SHELLFMT_SCAN_PATH}" \
      -type f \
      -print0
  )
}

function read_shellfmt_options() {
  local option=""

  SHELLFMT_OPTIONS=()

  if [[ -z "${SHELLFMT_CONFIG_PATH}" ]]; then
    return 0
  fi

  while IFS= read -r option || [[ -n "${option}" ]]; do
    option="${option#"${option%%[![:space:]]*}"}"
    option="${option%"${option##*[![:space:]]}"}"

    if [[ -z "${option}" || "${option}" == \#* ]]; then
      continue
    fi

    SHELLFMT_OPTIONS+=("${option}")
  done <"${SHELLFMT_CONFIG_PATH}"
}

function main() {
  local shellfmt_exit_code=0
  local unformatted_file_count=0
  local has_findings=false
  local -a command=()
  local -a shell_files=()

  validate_inputs
  resolve_shellfmt_binary
  read_shellfmt_options

  mkdir --parents "$(dirname "${SHELLFMT_REPORT_PATH}")"

  while IFS= read -r -d '' file_path; do
    shell_files+=("${file_path}")
  done < <(find_shell_files)

  if [[ "${#shell_files[@]}" -eq 0 ]]; then
    : >"${SHELLFMT_REPORT_PATH}"

    echo "[INFO] No files matched SHELLFMT_INCLUDE_PATTERNS."
    echo "SHELLFMT_UNFORMATTED_FILE_COUNT=0"
    echo "SHELLFMT_HAS_FINDINGS=false"
    echo "SHELLFMT_REPORT_PATH=${SHELLFMT_REPORT_PATH}"

    return 0
  fi

  command=(
    "${SHELLFMT_BIN}"
    -d
    "${SHELLFMT_OPTIONS[@]}"
    "${shell_files[@]}"
  )

  echo "[INFO] Running shellfmt against ${#shell_files[@]} file(s)."

  set +e
  "${command[@]}" >"${SHELLFMT_REPORT_PATH}"
  shellfmt_exit_code=$?
  set -e

  case "${shellfmt_exit_code}" in
  0) ;;
  1) ;;
  *)
    cat "${SHELLFMT_REPORT_PATH}" >&2
    fail "shellfmt failed with exit code ${shellfmt_exit_code}."
    ;;
  esac

  unformatted_file_count="$(
    grep \
      --fixed-strings \
      --count \
      -- \
      '--- ' \
      "${SHELLFMT_REPORT_PATH}" ||
      true
  )"

  if [[ "${unformatted_file_count}" -gt 0 ]]; then
    has_findings=true
    echo "[WARN] shellfmt reported ${unformatted_file_count} unformatted file(s)."
  else
    echo "[INFO] shellfmt completed with no formatting differences."
  fi

  echo "SHELLFMT_UNFORMATTED_FILE_COUNT=${unformatted_file_count}"
  echo "SHELLFMT_HAS_FINDINGS=${has_findings}"
  echo "SHELLFMT_REPORT_PATH=${SHELLFMT_REPORT_PATH}"

  if [[ "${SHELLFMT_FAIL_ON_FINDINGS}" == "true" && "${has_findings}" == "true" ]]; then
    exit 1
  fi
}

main "$@"
