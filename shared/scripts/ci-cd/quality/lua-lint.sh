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

USE_CACHE="${USE_CACHE:-false}"
declare -a cache_args=()

case "$USE_CACHE" in
true)
  cache_args=(--cache)
  ;;
false)
  cache_args=(--no-cache)
  ;;
*)
  quality_error "USE_CACHE must be true or false."
  exit 2
  ;;
esac

printf 'Settings: %s\nSelected files: %s\n' \
  "$SETTINGS_PATH" \
  "${#QUALITY_FILES[@]}" >"$REPORT_FILE"

declare -a lint_files=()

for file in "${QUALITY_FILES[@]}"; do
  lint_files+=("./$file")
done

if [[ "${#lint_files[@]}" -eq 0 ]]; then
  quality_log "No matching tracked Lua files."

  printf '\nNo matching tracked Lua files.\n' >>"$REPORT_FILE"

  quality_summary "## Lua lint

- Files selected: 0
- Result: No matching tracked Lua files; analysis skipped.
- Settings: \`$SETTINGS_PATH\`
"

  exit 0
fi

quality_log "Analyzing ${#lint_files[@]} Lua files in one Luacheck invocation."

status=0

luacheck \
  --config "$SETTINGS_PATH" \
  --no-default-config \
  "${cache_args[@]}" \
  --no-color \
  --codes \
  --formatter plain \
  "${lint_files[@]}" >"$QUALITY_TMP/current-report" 2>&1 || status=$?

{
  printf '\n=== Luacheck output ===\n'
  cat -- "$QUALITY_TMP/current-report"
} >>"$REPORT_FILE"

quality_print_report "$QUALITY_TMP/current-report"

case "$status" in
0)
  result="Clean"
  exit_code=0
  quality_log "No lint warnings or errors."
  ;;
1)
  result="Warnings detected"
  exit_code=1
  quality_log "Lint warnings detected. See the diagnostics above."
  ;;
*)
  result="Errors or execution failure"
  exit_code=2
  quality_error "Luacheck reported errors or failed with exit code $status."
  ;;
esac

{
  printf '\nResult: %s\n' "$result"
  printf 'Luacheck exit code: %s\n' "$status"
  printf 'Script exit code: %s\n' "$exit_code"
} >>"$REPORT_FILE"

quality_summary "## Lua lint

- Files selected: ${#lint_files[@]}
- Result: $result
- Luacheck exit code: $status
- Use cache: $USE_CACHE
- Settings: \`$SETTINGS_PATH\`

Detailed diagnostics are available in the job log and lint report.
"

exit "$exit_code"
