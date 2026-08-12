#!/usr/bin/env bash
set -euo pipefail

#########################################################
# Trivy security scan                                   #
#                                                       #
# Scans:                                                #
#   - Filesystems and source repositories               #
#   - Container images                                  #
#   - Dependency vulnerabilities                        #
#   - Exposed secrets                                   #
#   - IaC and configuration issues                      #
#                                                       #
# Required dependency:                                  #
#   - jq                                                #
#                                                       #
# Environment:                                          #
#   TRIVY_VERSION                                       #
#   TRIVY_INSTALL_DIR                                   #
#   TRIVY_BIN                                           #
#   TRIVY_SCAN_TYPE                                     #
#   TRIVY_SCAN_PATH                                     #
#   TRIVY_IMAGE_REF                                     #
#   TRIVY_SCANNERS                                      #
#   TRIVY_SEVERITY                                      #
#   TRIVY_IGNORE_UNFIXED                                #
#   TRIVY_CONFIG_PATH                                   #
#   TRIVY_SKIP_DIRS                                     #
#   TRIVY_REPORT_DIR                                    #
#   TRIVY_CACHE_DIR                                     #
#   TRIVY_FAIL_ON_FINDINGS                              #
#########################################################

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_REPOSITORY_ROOT="$(cd "${_DIR}/../../../.." && pwd)"

source "${_REPOSITORY_ROOT}/shared/scripts/bash/_util/is-installed.sh"

TRIVY_VERSION="${TRIVY_VERSION:-0.68.1}"
TRIVY_INSTALL_DIR="${TRIVY_INSTALL_DIR:-${HOME}/.local/bin}"
TRIVY_BIN="${TRIVY_BIN:-}"
TRIVY_SCAN_TYPE="${TRIVY_SCAN_TYPE:-filesystem}"
TRIVY_SCAN_PATH="${TRIVY_SCAN_PATH:-.}"
TRIVY_IMAGE_REF="${TRIVY_IMAGE_REF:-}"
TRIVY_SCANNERS="${TRIVY_SCANNERS:-vuln,secret,misconfig}"
TRIVY_SEVERITY="${TRIVY_SEVERITY:-HIGH,CRITICAL}"
TRIVY_IGNORE_UNFIXED="${TRIVY_IGNORE_UNFIXED:-true}"
TRIVY_CONFIG_PATH="${TRIVY_CONFIG_PATH:-}"
TRIVY_SKIP_DIRS="${TRIVY_SKIP_DIRS:-}"
TRIVY_REPORT_DIR="${TRIVY_REPORT_DIR:-./reports/trivy}"
TRIVY_CACHE_DIR="${TRIVY_CACHE_DIR:-}"
TRIVY_FAIL_ON_FINDINGS="${TRIVY_FAIL_ON_FINDINGS:-false}"

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
    fail "${variable_name} must be either 'true' or 'false'; received: ${value}"
    ;;
  esac
}

function validate_inputs() {
  if [[ ! "${TRIVY_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    fail "TRIVY_VERSION must be a semantic version without a leading 'v'."
  fi

  case "${TRIVY_SCAN_TYPE}" in
  filesystem | image) ;;
  *)
    fail "TRIVY_SCAN_TYPE must be either 'filesystem' or 'image'."
    ;;
  esac

  validate_boolean "TRIVY_IGNORE_UNFIXED" "${TRIVY_IGNORE_UNFIXED}"
  validate_boolean "TRIVY_FAIL_ON_FINDINGS" "${TRIVY_FAIL_ON_FINDINGS}"

  if [[ -z "${TRIVY_SCANNERS}" ]]; then
    fail "TRIVY_SCANNERS cannot be empty."
  fi

  if [[ -z "${TRIVY_SEVERITY}" ]]; then
    fail "TRIVY_SEVERITY cannot be empty."
  fi

  if [[ "${TRIVY_SCAN_TYPE}" == "filesystem" && ! -e "${TRIVY_SCAN_PATH}" ]]; then
    fail "TRIVY_SCAN_PATH does not exist: ${TRIVY_SCAN_PATH}"
  fi

  if [[ "${TRIVY_SCAN_TYPE}" == "image" && -z "${TRIVY_IMAGE_REF}" ]]; then
    fail "TRIVY_IMAGE_REF is required when TRIVY_SCAN_TYPE=image."
  fi

  if [[ -n "${TRIVY_CONFIG_PATH}" && ! -f "${TRIVY_CONFIG_PATH}" ]]; then
    fail "TRIVY_CONFIG_PATH does not exist: ${TRIVY_CONFIG_PATH}"
  fi

  if ! is_installed jq; then
    fail "jq is required to count Trivy findings and enforce scan policy."
  fi
}

function resolve_trivy_binary() {
  if [[ -n "${TRIVY_BIN}" ]]; then
    [[ -x "${TRIVY_BIN}" ]] || fail "TRIVY_BIN is not executable: ${TRIVY_BIN}"

    return 0
  fi

  if [[ -x "${TRIVY_INSTALL_DIR}/trivy" ]]; then
    TRIVY_BIN="${TRIVY_INSTALL_DIR}/trivy"

    return 0
  fi

  if is_installed trivy; then
    TRIVY_BIN="$(command -v trivy)"

    return 0
  fi

  echo "[INFO] Trivy is not installed; installing v${TRIVY_VERSION}"

  TRIVY_VERSION="${TRIVY_VERSION}" \
    TRIVY_INSTALL_DIR="${TRIVY_INSTALL_DIR}" \
    "${_REPOSITORY_ROOT}/shared/scripts/bash/installers/install-trivy.sh"

  TRIVY_BIN="${TRIVY_INSTALL_DIR}/trivy"
}

function build_scan_command() {
  local json_report="${1}"
  local target=""
  local trivy_subcommand=""
  local directory=""

  case "${TRIVY_SCAN_TYPE}" in
  filesystem)
    trivy_subcommand="fs"
    target="${TRIVY_SCAN_PATH}"
    ;;
  image)
    trivy_subcommand="image"
    target="${TRIVY_IMAGE_REF}"
    ;;
  esac

  TRIVY_COMMAND=(
    "${TRIVY_BIN}"
    "${trivy_subcommand}"
    --format json
    --output "${json_report}"
    --exit-code 0
    --no-progress
    --scanners "${TRIVY_SCANNERS}"
    --severity "${TRIVY_SEVERITY}"
    --ignore-unfixed="${TRIVY_IGNORE_UNFIXED}"
  )

  if [[ -n "${TRIVY_CONFIG_PATH}" ]]; then
    TRIVY_COMMAND+=(--config "${TRIVY_CONFIG_PATH}")
  fi

  if [[ -n "${TRIVY_CACHE_DIR}" ]]; then
    TRIVY_COMMAND+=(--cache-dir "${TRIVY_CACHE_DIR}")
  fi

  if [[ -n "${TRIVY_SKIP_DIRS}" ]]; then
    IFS=',' read -r -a directories <<<"${TRIVY_SKIP_DIRS}"

    for directory in "${directories[@]}"; do
      directory="${directory#"${directory%%[![:space:]]*}"}"
      directory="${directory%"${directory##*[![:space:]]}"}"

      if [[ -n "${directory}" ]]; then
        TRIVY_COMMAND+=(--skip-dirs "${directory}")
      fi
    done
  fi

  TRIVY_COMMAND+=("${target}")
}

function count_findings() {
  local json_report="${1}"

  jq '
    [
      .Results[]?
      | (.Vulnerabilities // [])[],
        (.Misconfigurations // [])[],
        (.Secrets // [])[]
    ]
    | length
  ' "${json_report}"
}

function main() {
  local json_report=""
  local sarif_report=""
  local finding_count=""
  local has_findings="false"

  validate_inputs
  resolve_trivy_binary

  mkdir --parents "${TRIVY_REPORT_DIR}"

  json_report="${TRIVY_REPORT_DIR}/trivy-${TRIVY_SCAN_TYPE}-results.json"
  sarif_report="${TRIVY_REPORT_DIR}/trivy-${TRIVY_SCAN_TYPE}-results.sarif"

  echo "[INFO] Trivy version:"
  "${TRIVY_BIN}" --version

  build_scan_command "${json_report}"

  echo "[INFO] Running Trivy ${TRIVY_SCAN_TYPE} scan"
  printf '[INFO] Command:'
  printf ' %q' "${TRIVY_COMMAND[@]}"
  printf '\n'

  "${TRIVY_COMMAND[@]}"

  echo "[INFO] Converting JSON report to SARIF"
  "${TRIVY_BIN}" convert \
    --format sarif \
    --output "${sarif_report}" \
    "${json_report}"

  finding_count="$(count_findings "${json_report}")"

  if [[ "${finding_count}" -gt 0 ]]; then
    has_findings="true"
    echo "[WARN] Trivy reported ${finding_count} finding(s)."
  else
    echo "[INFO] Trivy completed with no findings."
  fi

  echo "TRIVY_JSON_REPORT=${json_report}"
  echo "TRIVY_SARIF_REPORT=${sarif_report}"
  echo "TRIVY_FINDING_COUNT=${finding_count}"
  echo "TRIVY_HAS_FINDINGS=${has_findings}"

  if [[ "${TRIVY_FAIL_ON_FINDINGS}" == "true" && "${has_findings}" == "true" ]]; then
    echo "[ERROR] Trivy policy failed: ${finding_count} finding(s) reported."
    exit 1
  fi
}

main "$@"
