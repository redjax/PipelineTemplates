#!/usr/bin/env bash
set -euo pipefail

_JQ_INST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

## Load utilities
source "${_JQ_INST_DIR}/../_util/is-installed.sh"
source "${_JQ_INST_DIR}/../_util/detect-platform.sh"

function install_jq_linux() {
  local pkg_manager
  pkg_manager="$(detect_pkg_manager)"

  if [[ "$pkg_manager" == "unknown" ]]; then
    echo "Unable to detect package manager for jq installation" >&2
    exit 1
  fi

  case "$pkg_manager" in
  apt)
    sudo apt-get update -y
    sudo apt-get install -y jq
    ;;
  dnf)
    sudo dnf install -y jq
    ;;
  yum)
    sudo yum install -y jq
    ;;
  apk)
    sudo apk add jq
    ;;
  pacman)
    sudo pacman -Sy --noconfirm jq
    ;;
  *)
    echo "No supported package manager found. Falling back to binary install"
    install_jq_binary
    ;;
  esac
}

function install_jq_macos() {
  if command -v brew >/dev/null 2>&1; then
    brew install jq
  else
    echo "Homebrew not found. Please install brew or jq manually."
    exit 1
  fi
}

function install_jq_binary() {
  local os arch url bin_dir

  os="$(detect_os_family)"
  arch="$(detect_arch)"

  if [[ "$os" != "linux" ]]; then
    echo "Binary install only supported for Linux in this script."
    exit 1
  fi

  url="https://github.com/jqlang/jq/releases/latest/download/jq-linux-${arch}"
  bin_dir="/usr/local/bin"

  echo "Downloading jq from: $url"

  curl -L "$url" -o jq
  chmod +x jq
  sudo mv jq "$bin_dir/jq"

  echo "jq installed to $bin_dir/jq"
}

function main() {
  if is_installed jq; then
    echo "jq is already installed"
    jq --version
    exit 0
  fi

  local os
  os="$(detect_os_family)"

  case "$os" in
  linux)
    install_jq_linux
    ;;
  macos)
    install_jq_macos
    ;;
  *)
    echo "Unsupported OS: $os"
    exit 1
    ;;
  esac

  echo "jq installation complete"
  jq --version
}

main "$@"
