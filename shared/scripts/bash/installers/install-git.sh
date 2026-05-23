#!/usr/bin/env bash
set -euo pipefail

#!/usr/bin/env bash
set -euo pipefail

_GIT_INST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

## Load utilities
source "${_GIT_INST_DIR}/../_util/is-installed.sh"
source "${_GIT_INST_DIR}/../_util/detect-platform.sh"

function install_git_linux() {
  local pkg_manager
  pkg_manager="$(detect_pkg_manager)"

  if [[ "$pkg_manager" == "unknown" ]]; then
    echo "Unable to detect package manager for git installation" >&2
    exit 1
  fi

  case "$pkg_manager" in
  apt)
    sudo apt-get update -y
    sudo apt-get install -y git
    ;;
  dnf)
    sudo dnf install -y git
    ;;
  yum)
    sudo yum install -y git
    ;;
  apk)
    sudo apk update
    sudo apk add git
    ;;
  pacman)
    sudo pacman -Syu --noconfirm git
    ;;
  *)
    echo "No supported package manager found: $pkg_manager" >&2
    echo "Falling back to manual installation may be required." >&2
    return 1
    ;;
  esac
}

function install_git_macos() {
  if command -v brew >/dev/null 2>&1; then
    brew install git
  else
    echo "Homebrew not found. Please install brew or git manually."
    return 1
  fi
}

function main() {
  if is_installed git; then
    echo "git is already installed"
    git --version
    exit 0
  fi

  local os
  os="$(detect_os_family)"

  case "$os" in
  linux)
    install_git_linux
    ;;
  macos)
    install_git_macos
    ;;
  *)
    echo "Unsupported OS: $os"
    exit 1
    ;;
  esac

  echo "git installation complete"
  git --version
}

main "$@"
