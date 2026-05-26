#!/usr/bin/env bash
set -Eeuo pipefail

########################################################
# Checks if any Hugo-related files have changed in the #
# current history.                                     #
#                                                      #
# Write `hugo-changed=true|false` to `$GITHUB_OUTPUT`  #
########################################################

SOURCE_DIR="${HUGO_SOURCE_DIR:-.}"

cd "$SOURCE_DIR"

if git diff --name-only HEAD~1 | grep -qE '^(archetypes|assets|content|layouts|static|hugo\.yml)/'; then
  echo "hugo-changed=true" >>"${GITHUB_OUTPUT:-/dev/null}"
  echo "[INFO] Hugo-related changes detected."
else
  echo "hugo-changed=false" >>"${GITHUB_OUTPUT:-/dev/null}"
  echo "[INFO] No Hugo-related changes detected."
fi
