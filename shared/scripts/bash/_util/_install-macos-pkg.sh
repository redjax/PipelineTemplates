#!/usr/bin/env bash
set -euo pipefail

function install_macos_pkg() {
  local pkg="$1"

  shift || true

  local resolved_pkg="$pkg"

  for arg in "$@"; do
    if [[ "$arg" == "brew="* ]]; then
      resolved_pkg="${arg#*=}"
      break
    fi
  done

  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found" >&2
    return 1
  fi

  brew install "$resolved_pkg"
}
