#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
)"

# shellcheck source=lua-common.sh
source "$SCRIPT_DIR/lua-common.sh"

quality_init \
  "lua-format" \
  "config/lua/stylua.toml" \
  ".stylua.toml" \
  "stylua.toml"

if ! command -v stylua >/dev/null; then
  quality_error "StyLua is not installed or is not in PATH."
  exit 2
fi

FIX="${FIX:-false}"

case "$FIX" in
true | false) ;;
*)
  quality_error "FIX must be true or false."
  exit 2
  ;;
esac

REPORT_FILE="$REPORT_DIR/stylua.txt"
DIFF_FILE="$REPORT_DIR/format.diff"
PATCH_FILE="$REPORT_DIR/format.patch"

: >"$REPORT_FILE"
: >"$DIFF_FILE"
rm -f -- "$PATCH_FILE"

printf 'Settings: %s\nSelected files: %s\nFix: %s\n' \
  "$SETTINGS_PATH" \
  "${#QUALITY_FILES[@]}" \
  "$FIX" >>"$REPORT_FILE"

declare -a changed_files=()
declare -a formatted_files=()

error_files=0
index=0

for file in "${QUALITY_FILES[@]}"; do
  index=$((index + 1))

  formatted="$QUALITY_TMP/formatted-$index"
  stderr_file="$QUALITY_TMP/stderr-$index"

  quality_log "Checking formatting: $file"

  status=0

  stylua \
    --config-path "$SETTINGS_PATH" \
    --no-editorconfig \
    --verify \
    --stdin-filepath "$file" \
    - <"$file" >"$formatted" 2>"$stderr_file" || status=$?

  if [[ -s "$stderr_file" ]]; then
    quality_print_report "$stderr_file"

    {
      printf '\n=== %s: formatter diagnostics ===\n' "$file"
      cat -- "$stderr_file"
    } >>"$REPORT_FILE"
  fi

  if [[ "$status" -ne 0 ]]; then
    error_files=$((error_files + 1))
    quality_error "StyLua returned exit code $status for: $file"
    continue
  fi

  compare_status=0
  cmp -s -- "$file" "$formatted" || compare_status=$?

  case "$compare_status" in
  0)
    printf 'Formatted correctly: %s\n' "$file" >>"$REPORT_FILE"
    continue
    ;;
  1) ;;
  *)
    quality_error "Could not compare formatted output for: $file"
    exit 2
    ;;
  esac

  changed_files+=("$file")
  formatted_files+=("$formatted")

  printf 'Formatting differences: %s\n' "$file" >>"$REPORT_FILE"

  diff_status=0

  diff \
    -u \
    --label "a/$file" \
    --label "b/$file" \
    -- "$file" "$formatted" >"$QUALITY_TMP/current-diff" || diff_status=$?

  if [[ "$diff_status" -gt 1 ]]; then
    quality_error "Could not generate formatting diff for: $file"
    exit 2
  fi

  cat -- "$QUALITY_TMP/current-diff" >>"$DIFF_FILE"
  quality_print_report "$QUALITY_TMP/current-diff"
done

fixed_files=0

if [[ "$FIX" == true && "$error_files" -eq 0 ]]; then
  for index in "${!changed_files[@]}"; do
    file="${changed_files[$index]}"
    formatted="${formatted_files[$index]}"

    # Preserve the existing file's permissions.
    cat -- "$formatted" >"$file"

    fixed_files=$((fixed_files + 1))
    quality_log "Fixed: $file"
  done

  if [[ "${#changed_files[@]}" -gt 0 ]]; then
    : >"$PATCH_FILE"

    for file in "${changed_files[@]}"; do
      git --no-pager diff \
        --no-ext-diff \
        --binary \
        --full-index \
        -- "./$file" >>"$PATCH_FILE"
    done

    quality_log "Formatting patch: $PATCH_FILE"
  fi
fi

if [[ "${#QUALITY_FILES[@]}" -eq 0 ]]; then
  quality_log "No matching tracked Lua files."
fi

quality_log "Files requiring formatting: ${#changed_files[@]}"
quality_log "Files fixed: $fixed_files"
quality_log "Files with formatter errors: $error_files"

{
  printf '\nFiles requiring formatting: %s\n' "${#changed_files[@]}"
  printf 'Files fixed: %s\n' "$fixed_files"
  printf 'Files with formatter errors: %s\n' "$error_files"
} >>"$REPORT_FILE"

quality_summary "## Lua formatting

- Files selected: ${#QUALITY_FILES[@]}
- Files requiring formatting: ${#changed_files[@]}
- Files fixed: $fixed_files
- Files with formatter errors: $error_files
- Fix enabled: $FIX
- Settings: \`$SETTINGS_PATH\`

No commits or pushes are performed.
"

if [[ "$error_files" -gt 0 ]]; then
  exit 2
fi

if [[ "$FIX" == false && "${#changed_files[@]}" -gt 0 ]]; then
  exit 1
fi

exit 0
