#!/usr/bin/env bash
set -euo pipefail

function install_macos_pkg() {
  local pkg="$1"

  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found" >&2
    return 1
  fi

  brew install "$pkg"
}
