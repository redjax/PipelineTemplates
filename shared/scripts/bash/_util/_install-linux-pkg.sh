#!/usr/bin/env bash
set -euo pipefail

## Source platform utils
source "$(dirname "${BASH_SOURCE[0]}")/detect-platform.sh"

## Install a package on Linux. Detects some (not all) OS families
#  and selects the package manager, if able.
function install_linux_pkg() {
  local pkg="$1"

  local pkg_manager
  pkg_manager="$(detect_pkg_manager)"

  if [[ "$pkg_manager" == "unknown" ]]; then
    echo "Unable to detect package manager" >&2
    return 1
  fi

  case "$pkg_manager" in
  apt)
    sudo apt-get update -y
    sudo apt-get install -y "$pkg"
    ;;
  dnf)
    sudo dnf install -y "$pkg"
    ;;
  yum)
    sudo yum install -y "$pkg"
    ;;
  apk)
    sudo apk add "$pkg"
    ;;
  pacman)
    sudo pacman -Sy --noconfirm "$pkg"
    ;;
  *)
    echo "Unsupported package manager: $pkg_manager" >&2
    return 1
    ;;
  esac
}
