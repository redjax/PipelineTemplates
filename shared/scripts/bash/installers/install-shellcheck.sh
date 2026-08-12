#!/usr/bin/env bash
set -euo pipefail

#########################################################
# Install ShellCheck                                    #
#                                                       #
# Installs:                                             #
#   https://github.com/koalaman/shellcheck              #
#                                                       #
# Environment:                                          #
#   SHELLCHECK_VERSION       Version without leading v  #
#   SHELLCHECK_INSTALL_DIR   Destination directory      #
#   SHELLCHECK_FORCE_INSTALL Reinstall when true        #
#########################################################

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${_DIR}/../_util/is-installed.sh"

SHELLCHECK_VERSION="${SHELLCHECK_VERSION:-0.10.0}"
SHELLCHECK_INSTALL_DIR="${SHELLCHECK_INSTALL_DIR:-${HOME}/.local/bin}"
SHELLCHECK_FORCE_INSTALL="${SHELLCHECK_FORCE_INSTALL:-false}"

function fail() {
  echo "[ERROR] $*" >&2
  exit 1
}

function validate_inputs() {
  if [[ ! "${SHELLCHECK_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    fail "SHELLCHECK_VERSION must be a semantic version without a leading 'v'."
  fi

  case "${SHELLCHECK_FORCE_INSTALL}" in
  true | false) ;;
  *)
    fail "SHELLCHECK_FORCE_INSTALL must be either 'true' or 'false'."
    ;;
  esac
}

function installed_version() {
  local binary="${1}"

  "${binary}" --version 2>/dev/null |
    awk '/^version:/ { print $2; exit }'
}

function shellcheck_is_installed() {
  local binary=""
  local version=""

  if [[ "${SHELLCHECK_FORCE_INSTALL}" == "true" ]]; then
    return 1
  fi

  if [[ -x "${SHELLCHECK_INSTALL_DIR}/shellcheck" ]]; then
    binary="${SHELLCHECK_INSTALL_DIR}/shellcheck"
  elif is_installed shellcheck; then
    binary="$(command -v shellcheck)"
  else
    return 1
  fi

  version="$(installed_version "${binary}")"

  if [[ "${version}" != "${SHELLCHECK_VERSION}" ]]; then
    echo "[INFO] ShellCheck ${version:-unknown} is installed, but v${SHELLCHECK_VERSION} was requested."
    return 1
  fi

  echo "[INFO] ShellCheck v${SHELLCHECK_VERSION} is already installed: ${binary}"
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
    echo "linux.x86_64"
    ;;
  Linux:aarch64 | Linux:arm64)
    echo "linux.aarch64"
    ;;
  Darwin:x86_64)
    echo "darwin.x86_64"
    ;;
  Darwin:arm64)
    echo "darwin.aarch64"
    ;;
  *)
    fail "Unsupported ShellCheck platform: ${operating_system} ${architecture}"
    ;;
  esac
}

function download_and_install_shellcheck() {
  (
    local platform_suffix
    local archive_name
    local release_url
    local temporary_directory
    local archive_path
    local binary_path

    platform_suffix="$(get_platform_suffix)"
    archive_name="shellcheck-v${SHELLCHECK_VERSION}.${platform_suffix}.tar.xz"
    release_url="https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}"
    temporary_directory="$(mktemp --directory)"
    archive_path="${temporary_directory}/${archive_name}"

    trap 'rm --force --recursive "${temporary_directory:-}"' EXIT

    echo "[INFO] Downloading ShellCheck v${SHELLCHECK_VERSION}"
    echo "[INFO] Asset URL: ${release_url}/${archive_name}"

    curl --fail \
      --location \
      --retry 3 \
      --silent \
      --show-error \
      --output "${archive_path}" \
      "${release_url}/${archive_name}"

    tar \
      --extract \
      --xz \
      --file "${archive_path}" \
      --directory "${temporary_directory}"

    binary_path="$(
      find "${temporary_directory}" \
        -type f \
        -name shellcheck \
        -perm -u+x \
        -print \
        -quit
    )"

    if [[ -z "${binary_path}" ]]; then
      fail "ShellCheck binary was not found after extracting ${archive_name}."
    fi

    mkdir --parents "${SHELLCHECK_INSTALL_DIR}"

    install \
      --mode 0755 \
      "${binary_path}" \
      "${SHELLCHECK_INSTALL_DIR}/shellcheck"
  )
}

function add_to_github_path() {
  if [[ -n "${GITHUB_PATH:-}" ]]; then
    echo "${SHELLCHECK_INSTALL_DIR}" >>"${GITHUB_PATH}"
  fi
}

function main() {
  validate_inputs

  if shellcheck_is_installed; then
    return 0
  fi

  download_and_install_shellcheck
  add_to_github_path

  echo "[INFO] ShellCheck installation complete"
  "${SHELLCHECK_INSTALL_DIR}/shellcheck" --version
}

main "$@"
