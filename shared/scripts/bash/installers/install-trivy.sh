#!/usr/bin/env bash
set -euo pipefail

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${_DIR}/../_util/is-installed.sh"

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
#                                                       #
#########################################################

TRIVY_VERSION="${TRIVY_VERSION:-0.68.1}"
TRIVY_INSTALL_DIR="${TRIVY_INSTALL_DIR:-${HOME}/.local/bin}"
TRIVY_FORCE_INSTALL="${TRIVY_FORCE_INSTALL:-false}"

function fail() {
  echo "[ERROR] $*" >&2
  exit 1
}

function validate_version() {
  if [[ ! "${TRIVY_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    fail "TRIVY_VERSION must be a semantic version without a leading 'v'. Example: 0.68.1"
  fi
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

  if [[ -x "${TRIVY_INSTALL_DIR}/trivy" ]]; then
    binary="${TRIVY_INSTALL_DIR}/trivy"
  elif is_installed trivy; then
    binary="$(command -v trivy)"
  else
    return 1
  fi

  if [[ "${TRIVY_FORCE_INSTALL}" == "true" ]]; then
    return 1
  fi

  echo "[INFO] Trivy is already installed: ${binary}"
  "${binary}" --version

  return 0
}

function download_and_verify_trivy() {
  local asset_suffix
  local asset_name
  local checksums_name
  local release_url
  local temporary_directory

  asset_suffix="$(get_platform_asset_suffix)"
  asset_name="trivy_${TRIVY_VERSION}_${asset_suffix}.tar.gz"
  checksums_name="trivy_${TRIVY_VERSION}_checksums.txt"
  release_url="https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}"
  temporary_directory="$(mktemp --directory)"

  trap 'rm --force --recursive "${temporary_directory}"' RETURN

  echo "[INFO] Downloading Trivy v${TRIVY_VERSION}"
  echo "[INFO] Asset: ${asset_name}"

  curl --fail \
    --location \
    --retry 3 \
    --silent \
    --show-error \
    --output "${temporary_directory}/${asset_name}" \
    "${release_url}/${asset_name}"

  curl --fail \
    --location \
    --retry 3 \
    --silent \
    --show-error \
    --output "${temporary_directory}/${checksums_name}" \
    "${release_url}/${checksums_name}"

  (
    cd "${temporary_directory}"

    grep --fixed-strings " ${asset_name}" "${checksums_name}" |
      sha256sum --check --strict
  )

  mkdir --parents "${TRIVY_INSTALL_DIR}"

  tar --extract \
    --gzip \
    --file "${temporary_directory}/${asset_name}" \
    --directory "${temporary_directory}" \
    trivy

  install \
    --mode 0755 \
    "${temporary_directory}/trivy" \
    "${TRIVY_INSTALL_DIR}/trivy"
}

function add_to_github_path() {
  if [[ -n "${GITHUB_PATH:-}" ]]; then
    echo "${TRIVY_INSTALL_DIR}" >>"${GITHUB_PATH}"
  fi
}

function main() {
  validate_version

  if trivy_is_installed; then
    return 0
  fi

  download_and_verify_trivy
  add_to_github_path

  echo "[INFO] Trivy installation complete"
  "${TRIVY_INSTALL_DIR}/trivy" --version
}

main "$@"
