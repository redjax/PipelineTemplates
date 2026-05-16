#!/usr/bin/env bash
set -euo pipefail

########################################
# Utility script to check if a command #
# is available in the shell.           #
#                                      #
# Usage: is-installed.sh <cmd>         #
#                                      #
# Returns 0 if available, 1 otherwise  #
########################################

CHECK_CMD="${1:-}"

if [[ -z "$CHECK_CMD" ]]; then
  echo "[ERROR] No command was given" >&2
  exit 1
fi

if command -v "$CHECK_CMD" >/dev/null 2>&1; then
  exit 0
else
  exit 1
fi
