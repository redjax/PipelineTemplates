#!/usr/bin/env bash
set -euo pipefail

_UTIL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${_UTIL_DIR}/detect-platform.sh"
source "${_UTIL_DIR}/_install-linux-pkg.sh"
source "${_UTIL_DIR}/_install-macos-pkg.sh"

## Install a package on Linux or macOS. Attempts to detect the OS
#  and package manager.
function install_pkg() {
  local pkg="$1"

  local os
  os="$(detect_os_family)"

  case "$os" in
  linux)
    install_linux_pkg "$pkg"
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
