#!/usr/bin/env bash
set -euo pipefail

#########################################################
# Install Trivy                                         #
#                                                       #
# Installs:                                             #
#   https://github.com/aquasecurity/trivy               #
#                                                       #
# Environment:                                          #
#   TRIVY_VERSION       Release version, no leading v   #
#   TRIVY_INSTALL_DIR   Destination directory           #
#   TRIVY_FORCE_INSTALL Reinstall even when present     #
#########################################################

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${_DIR}/../_util/is-installed.sh"

TRIVY_VERSION="${TRIVY_VERSION:-0.73.0}"
TRIVY_INSTALL_DIR="${TRIVY_INSTALL_DIR:-${HOME}/.local/bin}"
TRIVY_FORCE_INSTALL="${TRIVY_FORCE_INSTALL:-false}"

function fail() {
  echo "[ERROR] $*" >&2
  exit 1
}

function validate_version() {
  if [[ ! "${TRIVY_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    fail "TRIVY_VERSION must be a semantic version without a leading 'v'. Example: 0.73.0"
  fi
}

function validate_boolean() {
  case "${TRIVY_FORCE_INSTALL}" in
  true | false) ;;
  *)
    fail "TRIVY_FORCE_INSTALL must be either 'true' or 'false'."
    ;;
  esac
}

function get_platform_asset_suffix() {
  local os
  local architecture

  os="$(uname -s)"
  architecture="$(uname -m)"

  case "${os}:${architecture}" in
  Linux:x86_64 | Linux:amd64)
    echo "Linux-64bit"
    ;;
  Linux:aarch64 | Linux:arm64)
    echo "Linux-ARM64"
    ;;
  Darwin:x86_64)
    echo "macOS-64bit"
    ;;
  Darwin:arm64)
    echo "macOS-ARM64"
    ;;
  *)
    fail "Unsupported Trivy platform: ${os} ${architecture}"
    ;;
  esac
}

function installed_version() {
  local binary="${1}"

  "${binary}" --version 2>/dev/null |
    awk '/^Version:/ { print $2; exit }'
}

function trivy_is_installed() {
  local binary=""
  local version=""

  if [[ "${TRIVY_FORCE_INSTALL}" == "true" ]]; then
    return 1
  fi

  if [[ -x "${TRIVY_INSTALL_DIR}/trivy" ]]; then
    binary="${TRIVY_INSTALL_DIR}/trivy"
  elif is_installed trivy; then
    binary="$(command -v trivy)"
  else
    return 1
  fi

  version="$(installed_version "${binary}")"

  if [[ "${version}" != "${TRIVY_VERSION}" ]]; then
    echo "[INFO] Trivy ${version:-unknown} is installed, but v${TRIVY_VERSION} was requested."
    return 1
  fi

  echo "[INFO] Trivy v${TRIVY_VERSION} is already installed: ${binary}"
  "${binary}" --version

  return 0
}

function calculate_sha256() {
  local file_path="${1}"

  if is_installed sha256sum; then
    sha256sum "${file_path}" | awk '{ print $1 }'
    return 0
  fi

  if is_installed shasum; then
    shasum --algorithm 256 "${file_path}" | awk '{ print $1 }'
    return 0
  fi

  fail "Neither sha256sum nor shasum is installed; cannot verify the Trivy archive."
}

function verify_archive_checksum() {
  local archive_path="${1}"
  local asset_name="${2}"
  local checksums_path="${3}"
  local expected_checksum=""
  local actual_checksum=""

  expected_checksum="$(
    awk \
      -v asset_name="${asset_name}" \
      '$NF == asset_name { print $1; exit }' \
      "${checksums_path}"
  )"

  if [[ -z "${expected_checksum}" ]]; then
    fail "No checksum was found for ${asset_name} in ${checksums_path}."
  fi

  actual_checksum="$(calculate_sha256 "${archive_path}")"

  if [[ "${actual_checksum}" != "${expected_checksum}" ]]; then
    fail "Checksum validation failed for ${asset_name}."
  fi

  echo "[INFO] Trivy archive checksum verified"
}

function download_and_verify_trivy() {
  (
    local asset_suffix
    local asset_name
    local checksums_name
    local release_url
    local temporary_directory
    local archive_path
    local checksums_path

    asset_suffix="$(get_platform_asset_suffix)"
    asset_name="trivy_${TRIVY_VERSION}_${asset_suffix}.tar.gz"
    checksums_name="trivy_${TRIVY_VERSION}_checksums.txt"
    release_url="https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}"
    temporary_directory="$(mktemp --directory)"
    archive_path="${temporary_directory}/${asset_name}"
    checksums_path="${temporary_directory}/${checksums_name}"

    trap 'rm --force --recursive "${temporary_directory:-}"' EXIT

    echo "[INFO] Downloading Trivy v${TRIVY_VERSION}"
    echo "[INFO] Asset URL: ${release_url}/${asset_name}"

    curl --fail \
      --location \
      --retry 3 \
      --silent \
      --show-error \
      --output "${archive_path}" \
      "${release_url}/${asset_name}"

    echo "[INFO] Downloading Trivy checksum manifest"
    echo "[INFO] Checksums URL: ${release_url}/${checksums_name}"

    curl --fail \
      --location \
      --retry 3 \
      --silent \
      --show-error \
      --output "${checksums_path}" \
      "${release_url}/${checksums_name}"

    verify_archive_checksum \
      "${archive_path}" \
      "${asset_name}" \
      "${checksums_path}"

    mkdir --parents "${TRIVY_INSTALL_DIR}"

    tar --extract \
      --gzip \
      --file "${archive_path}" \
      --directory "${temporary_directory}" \
      trivy

    install \
      --mode 0755 \
      "${temporary_directory}/trivy" \
      "${TRIVY_INSTALL_DIR}/trivy"
  )
}

function add_to_github_path() {
  if [[ -n "${GITHUB_PATH:-}" ]]; then
    echo "${TRIVY_INSTALL_DIR}" >>"${GITHUB_PATH}"
  fi
}

function main() {
  validate_version
  validate_boolean

  if trivy_is_installed; then
    return 0
  fi

  download_and_verify_trivy
  add_to_github_path

  echo "[INFO] Trivy installation complete"
  "${TRIVY_INSTALL_DIR}/trivy" --version
}

main "$@"
