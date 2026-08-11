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
#                                                       #
#########################################################

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${_DIR}/../_util/is-installed.sh"
source "${_DIR}/../_util/install-github-release.sh"

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

function ensure_cosign() {
  if is_installed cosign; then
    return 0
  fi

  echo "[INFO] Installing cosign for Trivy signature verification"

  install_github_binary \
    sigstore/cosign \
    cosign

  if ! is_installed cosign; then
    fail "cosign installation failed; cannot verify the Trivy release artifact."
  fi
}

function download_and_verify_trivy() {
  local asset_suffix
  local asset_name
  local bundle_name
  local release_url
  local temporary_directory

  asset_suffix="$(get_platform_asset_suffix)"
  asset_name="trivy_${TRIVY_VERSION}_${asset_suffix}.tar.gz"
  bundle_name="${asset_name}.sigstore.json"
  release_url="https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}"
  temporary_directory="$(mktemp --directory)"

  trap 'rm --force --recursive "${temporary_directory}"' RETURN

  echo "[INFO] Downloading Trivy v${TRIVY_VERSION}"
  echo "[INFO] Asset URL: ${release_url}/${asset_name}"

  curl --fail \
    --location \
    --retry 3 \
    --silent \
    --show-error \
    --output "${temporary_directory}/${asset_name}" \
    "${release_url}/${asset_name}"

  echo "[INFO] Downloading Trivy Sigstore verification bundle"
  echo "[INFO] Bundle URL: ${release_url}/${bundle_name}"

  curl --fail \
    --location \
    --retry 3 \
    --silent \
    --show-error \
    --output "${temporary_directory}/${bundle_name}" \
    "${release_url}/${bundle_name}"

  ensure_cosign

  echo "[INFO] Verifying Trivy release signature"

  cosign verify-blob \
    "${temporary_directory}/${asset_name}" \
    --bundle "${temporary_directory}/${bundle_name}" \
    --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
    --certificate-identity="https://github.com/aquasecurity/trivy/.github/workflows/reusable-release.yaml@refs/tags/v${TRIVY_VERSION}"

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
