#!/usr/bin/env bash
set -euo pipefail

_CURL_INST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

## Load utilities
source "${_CURL_INST_DIR}/../_util/is-installed.sh"
source "${_CURL_INST_DIR}/../_util/detect-platform.sh"

function install_curl_linux() {
  local pkg_manager
  pkg_manager="$(detect_pkg_manager)"

  if [[ "$pkg_manager" == "unknown" ]]; then
    echo "Unable to detect package manager for curl installation" >&2
    exit 1
  fi

  case "$pkg_manager" in
  apt)
    sudo apt-get update -y
    sudo apt-get install -y curl
    ;;
  dnf)
    sudo dnf install -y curl
    ;;
  yum)
    sudo yum install -y curl
    ;;
  apk)
    sudo apk update
    sudo apk add curl
    ;;
  pacman)
    sudo pacman -Syu --noconfirm curl
    ;;
  *)
    echo "No supported package manager found: $pkg_manager" >&2
    echo "Falling back to manual installation may be required." >&2
    return 1
    ;;
  esac
}

function install_curl_macos() {
  if command -v brew >/dev/null 2>&1; then
    brew install curl
  else
    echo "Homebrew not found. Please install brew or curl manually."
    return 1
  fi
}

function main() {
  if is_installed curl; then
    echo "curl is already installed"
    curl --version
    exit 0
  fi

  local os
  os="$(detect_os_family)"

  case "$os" in
  linux)
    install_curl_linux
    ;;
  macos)
    install_curl_macos
    ;;
  *)
    echo "Unsupported OS: $os"
    exit 1
    ;;
  esac

  echo "curl installation complete"
  curl --version
}

main "$@"
