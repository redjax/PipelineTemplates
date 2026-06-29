#!/usr/bin/env bash
set -Eeuo pipefail

########################################################
# Checks if any Hugo-related files have changed in the #
# current history.                                     #
#                                                      #
# Write `hugo-changed=true|false` to `$GITHUB_OUTPUT`  #
########################################################

SOURCE_DIR="${HUGO_SOURCE_DIR:-.}"
MODE="${CHANGED_PATHS_MODE:-default}"

cd "$SOURCE_DIR"

default_paths=(
  "archetypes/**"
  "assets/**"
  "content/**"
  "data/**"
  "i18n/**"
  "layouts/**"
  "static/**"
  "themes/**"
  "modules/**"
  "config/**"
  "config.*"
  "hugo.*"
)

replace_paths=()
if [[ -n "${CHANGED_PATHS:-}" ]]; then
  mapfile -t replace_paths <<<"${CHANGED_PATHS}"
fi

paths=()
case "$MODE" in
default)
  paths=("${default_paths[@]}")
  ;;
replace)
  paths=("${replace_paths[@]}")
  ;;
append)
  paths=("${default_paths[@]}" "${replace_paths[@]}")
  ;;
*)
  echo "[ERROR] Invalid CHANGED_PATHS_MODE: $MODE" >&2
  exit 1
  ;;
esac

changed="false"

if [[ "${#paths[@]}" -eq 0 ]]; then
  changed="true"
else
  for pattern in "${paths[@]}"; do
    if git diff --name-only HEAD~1..HEAD -- "$pattern" | grep -q .; then
      changed="true"
      break
    fi
  done
fi

echo "hugo-changed=$changed" >>"${GITHUB_OUTPUT}"
echo "[INFO] hugo-changed=$changed"
