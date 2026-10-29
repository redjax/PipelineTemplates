#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"

# shellcheck source=lua-common.sh
source "$SCRIPT_DIR/lua-common.sh"

quality_init \
  "lua-lint" \
  "config/lua/.luacheckrc" \
  ".luacheckrc"

if ! command -v luacheck >/dev/null; then
  quality_error "Luacheck is not installed or is not in PATH."
  exit 2
fi

REPORT_FILE="$REPORT_DIR/luacheck.txt"
: >"$REPORT_FILE"

printf 'Settings: %s\nSelected files: %s\n' \
  "$SETTINGS_PATH" \
  "${#QUALITY_FILES[@]}" >>"$REPORT_FILE"

warning_files=0
error_files=0

for file in "${QUALITY_FILES[@]}"; do
  quality_log "Analyzing: $file"

  status=0

  luacheck \
    --config "$SETTINGS_PATH" \
    --no-default-config \
    --no-cache \
    --no-color \
    --codes \
    --formatter plain \
    "./$file" >"$QUALITY_TMP/current-report" 2>&1 || status=$?

  {
    printf '\n=== %s ===\n' "$file"
    cat -- "$QUALITY_TMP/current-report"
  } >>"$REPORT_FILE"

  quality_print_report "$QUALITY_TMP/current-report"

  case "$status" in
  0) ;;
  1)
    warning_files=$((warning_files + 1))
    ;;
  *)
    error_files=$((error_files + 1))
    quality_error "Luacheck returned exit code $status for: $file"
    ;;
  esac
done

if [[ "${#QUALITY_FILES[@]}" -eq 0 ]]; then
  quality_log "No matching tracked Lua files."
fi

quality_log "Files with warnings: $warning_files"
quality_log "Files with errors: $error_files"

{
  printf '\nFiles with warnings: %s\n' "$warning_files"
  printf 'Files with errors: %s\n' "$error_files"
} >>"$REPORT_FILE"

quality_summary "## Lua lint

- Files selected: ${#QUALITY_FILES[@]}
- Files with warnings: $warning_files
- Files with errors: $error_files
- Settings: \`$SETTINGS_PATH\`
"

if [[ "$error_files" -gt 0 ]]; then
  exit 2
fi

if [[ "$warning_files" -gt 0 ]]; then
  exit 1
fi

exit 0
