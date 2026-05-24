#!/usr/bin/env bash
set -euo pipefail

## Run command with sudo
function run_privileged() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}
