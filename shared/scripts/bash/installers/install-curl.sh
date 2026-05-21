#!/usr/bin/env bash
set -euo pipefail

_CURL_INST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

## Load utilities
source "${_CURL_INST_DIR}/../_util/is-installed.sh"
source "${_CURL_INST_DIR}/../_util/detect-platform.sh"

function install_curl_linux() {
  local pkg_manager
  pkg_manager="$(detect_pkg_manager)"

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
  *)
    echo "No supported package manager found." >&2
    ;;
  esac
}

function install_curl_macos() {
  if command -v curl >/dev/null 2>&1; then
    brew install curl
  else
    echo "Homebrew not found. Please install brew or curl manually."
    exit 1
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
