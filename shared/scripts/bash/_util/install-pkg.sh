#!/usr/bin/env bash
set -euo pipefail

_UTIL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${_UTIL_DIR}/detect-platform.sh"
source "${_UTIL_DIR}/_install-linux-pkg.sh"
source "${_UTIL_DIR}/_install-macos-pkg.sh"

## Install a package on Linux or macOS.
#
#  Usage:
#
#    install_pkg curl
#
#    install_pkg python3-pip \
#      apk=py3-pip \
#      pacman=python-pip
function install_pkg() {
  local pkg="$1"

  shift || true

  local os
  os="$(detect_os_family)"

  case "$os" in
  linux)
    install_linux_pkg "$pkg" "$@"
    ;;
  macos)
    install_macos_pkg "$pkg"
    ;;
  *)
    echo "Unsupported OS: $os" >&2
    return 1
    ;;
  esac
}
