#!/usr/bin/env bash

# Shared implementation for lua-lint.sh and lua-format.sh.
# Source this file; do not execute it directly.

quality_log() {
  printf '[INFO] %s\n' "$*"
}

quality_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

quality_print_report() {
  # Prefix tool output so it cannot issue GitHub workflow commands.
  sed 's/^/| /' "$1"
}

quality_summary() {
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf '%s\n' "$1" >>"$GITHUB_STEP_SUMMARY"
  fi
}

quality_read_lines() {
  local -n destination="$1"
  local value="$2"
  local line

  destination=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"

    # Trim leading and trailing whitespace.
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    [[ -n "$line" ]] && destination+=("$line")
  done <<<"$value"

  return 0
}

quality_cleanup() {
  if [[ -n "${QUALITY_TMP:-}" && -d "$QUALITY_TMP" ]]; then
    rm -rf -- "$QUALITY_TMP"
  fi
}

quality_unexpected_error() {
  trap - ERR
  quality_error "Unexpected execution failure near line $1."
  exit 2
}

quality_init() {
  local operation="$1"
  local fallback_relative="$2"
  shift 2
  local -a conventional_names=("$@")

  command -v git >/dev/null
  command -v realpath >/dev/null
  command -v mktemp >/dev/null

  QUALITY_TMP="$(mktemp -d)"
  trap quality_cleanup EXIT
  trap 'quality_unexpected_error "$LINENO"' ERR

  if [[ -n "${ROOT:-}" ]]; then
    ROOT="$(realpath -e -- "$ROOT")"
  else
    ROOT="$(git rev-parse --show-toplevel)"
    ROOT="$(realpath -e -- "$ROOT")"
  fi

  local common_directory
  common_directory="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
  )"

  TEMPLATES_ROOT="${TEMPLATES_ROOT:-$common_directory/../../../..}"
  TEMPLATES_ROOT="$(realpath -e -- "$TEMPLATES_ROOT")"

  REPORT_DIR="${REPORT_DIR:-${TMPDIR:-/tmp}/$operation-results}"
  mkdir -p -- "$REPORT_DIR"
  REPORT_DIR="$(realpath -e -- "$REPORT_DIR")"

  cd -- "$ROOT" || exit

  local requested="${SETTINGS_FILE:-}"
  local name

  SETTINGS_PATH=""

  if [[ -n "$requested" ]]; then
    if [[ "$requested" == /* ]]; then
      quality_error "SETTINGS_FILE must be repository-relative."
      exit 2
    fi

    if ! SETTINGS_PATH="$(realpath -e -- "$ROOT/$requested")"; then
      quality_error "Requested settings file does not exist: $requested"
      exit 2
    fi

    if [[ "$SETTINGS_PATH" != "$ROOT/"* ]]; then
      quality_error "Settings file must remain inside the repository."
      exit 2
    fi
  else
    for name in "${conventional_names[@]}"; do
      if [[ -f "$ROOT/$name" ]]; then
        SETTINGS_PATH="$(realpath -e -- "$ROOT/$name")"
        break
      fi
    done

    if [[ -z "$SETTINGS_PATH" ]]; then
      SETTINGS_PATH="$TEMPLATES_ROOT/$fallback_relative"
    fi
  fi

  if [[ ! -f "$SETTINGS_PATH" ]]; then
    quality_error "Settings file does not exist: $SETTINGS_PATH"
    exit 2
  fi

  declare -ga QUALITY_PATHS=()
  declare -ga QUALITY_EXCLUDES=()
  declare -ga QUALITY_FILES=()

  quality_read_lines QUALITY_PATHS "${SCAN_PATHS:-.}"
  quality_read_lines QUALITY_EXCLUDES "${EXCLUDE_PATHS:-}"

  if [[ "${#QUALITY_PATHS[@]}" -eq 0 ]]; then
    QUALITY_PATHS=(".")
  fi

  git ls-files \
    --stage \
    -z \
    -- "${QUALITY_PATHS[@]}" >"$QUALITY_TMP/tracked"

  local record metadata file mode _object stage resolved pattern
  local excluded

  while IFS= read -r -d '' record; do
    metadata="${record%%$'\t'*}"
    file="${record#*$'\t'}"

    read -r mode _object stage <<<"$metadata"

    # Only normal tracked files, not symlinks or submodules.
    [[ "$stage" == "0" ]] || continue
    [[ "$mode" == "100644" || "$mode" == "100755" ]] || continue
    [[ "$file" == *.lua ]] || continue
    [[ -f "$file" && ! -L "$file" ]] || continue

    resolved="$(realpath -e -- "$file")"
    [[ "$resolved" == "$ROOT/"* ]] || continue

    excluded=false

    for pattern in "${QUALITY_EXCLUDES[@]}"; do
      ## Exclusions intentionally use wildcard matching, e.g. vendor/*.
      # shellcheck disable=SC2053
      if [[ "$file" == $pattern ]]; then
        excluded=true
        break
      fi
    done

    if [[ "$excluded" == false ]]; then
      QUALITY_FILES+=("$file")
    fi
  done <"$QUALITY_TMP/tracked"

  quality_log "Repository: $ROOT"
  quality_log "Settings: $SETTINGS_PATH"
  quality_log "Selected Lua files: ${#QUALITY_FILES[@]}"
  quality_log "Reports: $REPORT_DIR"
}
