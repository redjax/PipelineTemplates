#!/usr/bin/env bash
set -euo pipefail

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
SHELLFMT_MODE="${SHELLFMT_MODE:-check}"
SHELLFMT_FAIL_ON_FINDINGS="${SHELLFMT_FAIL_ON_FINDINGS:-true}"

function fail() {
  echo "[ERROR] $*" >&2
  exit 2
}

function validate_inputs() {
  case "${SHELLFMT_MODE}" in
  check | write) ;;
  *)
    fail "SHELLFMT_MODE must be check or write."
    ;;
  esac

  case "${SHELLFMT_FAIL_ON_FINDINGS}" in
  true | false) ;;
  *)
    fail "SHELLFMT_FAIL_ON_FINDINGS must be true or false."
    ;;
  esac

  [[ -e "${SHELLFMT_SCAN_PATH}" ]] ||
    fail "SHELLFMT_SCAN_PATH does not exist: ${SHELLFMT_SCAN_PATH}"

  if [[ -n "${SHELLFMT_CONFIG_PATH}" ]]; then
    [[ -f "${SHELLFMT_CONFIG_PATH}" ]] ||
      fail "SHELLFMT_CONFIG_PATH does not exist: ${SHELLFMT_CONFIG_PATH}"
  fi
}

function resolve_shellfmt_binary() {
  if [[ -n "${SHELLFMT_BIN}" ]]; then
    [[ -x "${SHELLFMT_BIN}" ]] ||
      fail "SHELLFMT_BIN is not executable: ${SHELLFMT_BIN}"

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

  IFS=',' read -r -a include_patterns <<<"${SHELLFMT_INCLUDE_PATTERNS}"

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
  done < <(find "${SHELLFMT_SCAN_PATH}" -type f -print0)
}

function read_options() {
  local option

  SHELLFMT_OPTIONS=()

  [[ -n "${SHELLFMT_CONFIG_PATH}" ]] || return 0

  while IFS= read -r option || [[ -n "${option}" ]]; do
    option="${option#"${option%%[![:space:]]*}"}"
    option="${option%"${option##*[![:space:]]}"}"

    [[ -n "${option}" && "${option}" != \#* ]] || continue

    SHELLFMT_OPTIONS+=("${option}")
  done <"${SHELLFMT_CONFIG_PATH}"
}

function main() {
  local exit_code=0
  local write_exit_code=0
  local -a shell_files=()
  local -a command=()

  validate_inputs
  resolve_shellfmt_binary
  read_options

  mkdir --parents "$(dirname "${SHELLFMT_REPORT_PATH}")"

  while IFS= read -r -d '' file_path; do
    shell_files+=("${file_path}")
  done < <(find_shell_files)

  if [[ "${#shell_files[@]}" -eq 0 ]]; then
    : >"${SHELLFMT_REPORT_PATH}"
    echo "[INFO] No shellfmt files found."
    exit 0
  fi

  command=(
    "${SHELLFMT_BIN}"
    "${SHELLFMT_OPTIONS[@]}"
  )

  case "${SHELLFMT_MODE}" in
  check)
    command+=(-d)
    ;;
  write)
    command+=(-l)
    ;;
  esac

  command+=("${shell_files[@]}")

  printf '[INFO] Command:'
  printf ' %q' "${command[@]}"
  printf '\n'

  set +e
  "${command[@]}" >"${SHELLFMT_REPORT_PATH}" 2>&1
  exit_code=$?
  set -e

  case "${SHELLFMT_MODE}:${exit_code}" in
  check:0)
    echo "[INFO] shellfmt completed with no formatting differences."
    ;;

  check:1)
    echo "[WARN] shellfmt found formatting differences."

    if [[ "${SHELLFMT_FAIL_ON_FINDINGS}" == "true" ]]; then
      exit 1
    fi
    ;;

  write:0)
    if [[ -s "${SHELLFMT_REPORT_PATH}" ]]; then
      echo "[INFO] shellfmt will format listed files in the runner checkout."

      set +e

      "${SHELLFMT_BIN}" \
        "${SHELLFMT_OPTIONS[@]}" \
        -w \
        "${shell_files[@]}"

      write_exit_code=$?

      set -e

      if [[ "${write_exit_code}" -ne 0 ]]; then
        fail "shellfmt could not write formatted files. Exit code: ${write_exit_code}."
      fi

      echo "[INFO] shellfmt formatted listed files in the runner checkout."
    else
      echo "[INFO] shellfmt found no files requiring formatting."
    fi
    ;;

  *)
    cat "${SHELLFMT_REPORT_PATH}" >&2
    fail "shellfmt failed with exit code ${exit_code}."
    ;;
  esac
}

main "$@"
