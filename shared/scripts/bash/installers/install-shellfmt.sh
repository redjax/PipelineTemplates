#!/usr/bin/env bash
set -euo pipefail

#########################################################
# Install shellfmt                                      #
#                                                       #
# Installs:                                             #
#   https://github.com/mvdan/sh                         #
#                                                       #
# Environment:                                          #
#   SHELLFMT_VERSION       Version without leading v    #
#   SHELLFMT_INSTALL_DIR   Destination directory        #
#   SHELLFMT_FORCE_INSTALL Reinstall when true          #
#########################################################

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${_DIR}/../_util/is-installed.sh"

SHELLFMT_VERSION="${SHELLFMT_VERSION:-3.10.0}"
SHELLFMT_INSTALL_DIR="${SHELLFMT_INSTALL_DIR:-${HOME}/.local/bin}"
SHELLFMT_FORCE_INSTALL="${SHELLFMT_FORCE_INSTALL:-false}"

function fail() {
  echo "[ERROR] $*" >&2
  exit 1
}

function validate_inputs() {
  if [[ ! "${SHELLFMT_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    fail "SHELLFMT_VERSION must be a semantic version without a leading 'v'."
  fi

  case "${SHELLFMT_FORCE_INSTALL}" in
  true | false) ;;
  *)
    fail "SHELLFMT_FORCE_INSTALL must be either 'true' or 'false'."
    ;;
  esac
}

function installed_version() {
  local binary="${1}"

  "${binary}" --version 2>/dev/null |
    sed --quiet --regexp-extended 's/^v?([0-9]+\.[0-9]+\.[0-9]+)$/\1/p'
}

function shellfmt_is_installed() {
  local binary=""
  local version=""

  if [[ "${SHELLFMT_FORCE_INSTALL}" == "true" ]]; then
    return 1
  fi

  if [[ -x "${SHELLFMT_INSTALL_DIR}/shfmt" ]]; then
    binary="${SHELLFMT_INSTALL_DIR}/shfmt"
  elif is_installed shfmt; then
    binary="$(command -v shfmt)"
  else
    return 1
  fi

  version="$(installed_version "${binary}")"

  if [[ "${version}" != "${SHELLFMT_VERSION}" ]]; then
    echo "[INFO] shellfmt ${version:-unknown} is installed, but v${SHELLFMT_VERSION} was requested."
    return 1
  fi

  echo "[INFO] shellfmt v${SHELLFMT_VERSION} is already installed: ${binary}"
  "${binary}" --version

  return 0
}

function get_platform_suffix() {
  local operating_system
  local architecture

  operating_system="$(uname -s)"
  architecture="$(uname -m)"

  case "${operating_system}:${architecture}" in
  Linux:x86_64 | Linux:amd64)
    echo "linux_amd64"
    ;;
  Linux:aarch64 | Linux:arm64)
    echo "linux_arm64"
    ;;
  Darwin:x86_64)
    echo "darwin_amd64"
    ;;
  Darwin:arm64)
    echo "darwin_arm64"
    ;;
  *)
    fail "Unsupported shellfmt platform: ${operating_system} ${architecture}"
    ;;
  esac
}

function download_and_install_shellfmt() {
  (
    local platform_suffix
    local asset_name
    local release_url
    local temporary_directory
    local asset_path

    platform_suffix="$(get_platform_suffix)"
    asset_name="shfmt_v${SHELLFMT_VERSION}_${platform_suffix}"
    release_url="https://github.com/mvdan/sh/releases/download/v${SHELLFMT_VERSION}"
    temporary_directory="$(mktemp --directory)"
    asset_path="${temporary_directory}/${asset_name}"

    trap 'rm --force --recursive "${temporary_directory:-}"' EXIT

    echo "[INFO] Downloading shellfmt v${SHELLFMT_VERSION}"
    echo "[INFO] Asset URL: ${release_url}/${asset_name}"

    curl --fail \
      --location \
      --retry 3 \
      --silent \
      --show-error \
      --output "${asset_path}" \
      "${release_url}/${asset_name}"

    mkdir --parents "${SHELLFMT_INSTALL_DIR}"

    install \
      --mode 0755 \
      "${asset_path}" \
      "${SHELLFMT_INSTALL_DIR}/shfmt"
  )
}

function add_to_github_path() {
  if [[ -n "${GITHUB_PATH:-}" ]]; then
    echo "${SHELLFMT_INSTALL_DIR}" >>"${GITHUB_PATH}"
  fi
}

function main() {
  validate_inputs

  if shellfmt_is_installed; then
    return 0
  fi

  download_and_install_shellfmt
  add_to_github_path

  echo "[INFO] shellfmt installation complete"
  "${SHELLFMT_INSTALL_DIR}/shfmt" --version
}

main "$@"
