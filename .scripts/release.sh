#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

## IGNORE_KEYS: Temporarily exclude specific pipelines from auto-bumping
#  Note: Pipelines are "ignored by default" until added to versions.yml.
#  Use this to exclude pipelines that exist in the manifest but should
#  not be auto-bumped (e.g., during development or for manual-only versioning).
declare -a IGNORE_KEYS=(
  # "github/demo-hello"
)

MANIFEST="manifests/versions.yml"
DRY_RUN=0
VERBOSE=0
BUMP_TYPE="patch"  # patch, minor, or major
TEST_MODE=0
USE_YQ=0

## Detect if yq is available for YAML manipulation
if command -v yq >/dev/null 2>&1; then
  USE_YQ=1
fi

function usage() {
  cat <<EOF

Usage: ${0##*/} [OPTIONS]

Automatically bump versions in manifests/versions.yml for changed pipeline files.

Options:
  --dry-run           Show what would change without modifying files
  --verbose           Show detailed output for debugging
  --bump-type TYPE    Version component to bump: patch (default), minor, or major
  --test              Run in test mode with sample data
  -h, --help          Show this help message

Environment (optional - will auto-detect if not provided):
  CHANGED_FILES_FILE   Path to temp file of changed paths.
  BASE_MANIFEST_FILE   Path to base/merge-base manifest snapshot.

When run locally without environment variables, the script will automatically:
  - Detect changes against origin/main (or main if local-only)
  - Find the merge-base commit
  - Generate the list of changed files
  - Extract the base manifest from the merge-base

Examples:
  ${0##*/} --dry-run                       # Preview changes locally
  ${0##*/} --dry-run --verbose             # Preview with detailed output
  ${0##*/} --bump-type minor               # Bump minor version
  ${0##*/} --test                          # Run with test data

EOF
}

## Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    --bump-type)
      BUMP_TYPE="${2:?missing value for --bump-type}"
      if [[ ! "$BUMP_TYPE" =~ ^(patch|minor|major)$ ]]; then
        echo "[ERROR] Invalid bump type: $BUMP_TYPE (must be patch, minor, or major)" >&2
        exit 1
      fi
      shift 2
      ;;
    --test)
      TEST_MODE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

function log_verbose() {
  [[ "$VERBOSE" -eq 1 ]] && echo "[VERBOSE] $*" >&2
  return 0
}

function log_info() {
  echo "[INFO] $*" >&2
}

function log_error() {
  echo "[ERROR] $*" >&2
}

## Validate YAML file structure (basic check)
function validate_yaml() {
  local file="$1"
  
  if [[ ! -f "$file" ]]; then
    log_error "File does not exist: $file"
    return 1
  fi
  
  ## Basic YAML validation: check for valid key: value pairs
  if ! grep -qE '^[^:]+: ' "$file"; then
    log_error "Invalid YAML structure in: $file"
    return 1
  fi
  
  ## If yq is available, use it for more robust validation
  if [[ "$USE_YQ" -eq 1 ]]; then
    if ! yq eval '.' "$file" >/dev/null 2>&1; then
      log_error "YAML validation failed (yq): $file"
      return 1
    fi
  fi
  
  return 0
}

## Convert file path to manifest key
#  Extensible pattern: Add new pipeline platforms here
function path_to_key() {
  local path="$1"

  case "$path" in
    .github/workflows/*.yml|.github/workflows/*.yaml)
      local rel="${path#.github/workflows/}"
      rel="${rel%.*}"
      printf 'github/%s\n' "$rel"
      ;;
    gitlab/*.yml|gitlab/*.yaml|gitlab/*/*.yml|gitlab/*/*.yaml|gitlab/*/*/*.yml|gitlab/*/*/*.yaml)
      local rel="${path#gitlab/}"
      rel="${rel%.*}"
      printf 'gitlab/%s\n' "$rel"
      ;;
    concourse/*.yml|concourse/*.yaml)
      local rel="${path#concourse/}"
      rel="${rel%.*}"
      printf 'concourse/%s\n' "$rel"
      ;;
    woodpecker/*.yml|woodpecker/*.yaml)
      local rel="${path#woodpecker/}"
      rel="${rel%.*}"
      printf 'woodpecker/%s\n' "$rel"
      ;;
    *)
      return 1
      ;;
  esac
}

## Set a value in the manifest file
#  Uses yq if available, falls back to awk
function set_manifest_value() {
  local file="$1"
  local key="$2"
  local value="$3"

  if [[ "$USE_YQ" -eq 1 ]]; then
    ## Use yq for robust YAML manipulation
    if ! yq eval ".\"${key}\" = \"${value}\"" -i "$file"; then
      return 1
    fi
  else
    ## Fallback to awk
    if ! awk -v k="$key" -v v="$value" '
      $1 == k ":" { print k ": " v; next }
      { print }
    ' "$file" > "${file}.tmp"; then
      return 1
    fi
    
    if ! mv "${file}.tmp" "$file"; then
      rm -f "${file}.tmp"
      return 1
    fi
  fi
  
  return 0
}

## Look up a value from the manifest
function lookup_value() {
  local file="$1"
  local key="$2"
  
  if [[ "$USE_YQ" -eq 1 ]]; then
    ## Use yq for robust YAML parsing
    yq eval ".\"${key}\"" "$file" 2>/dev/null | grep -v '^null$' || true
  else
    ## Fallback to awk
    awk -v k="$key" '$1 == k ":" { print $2; exit }' "$file"
  fi
}

## Bump version according to bump type
function bump_version() {
  local version="$1"
  local bump_type="$2"
  
  if [[ ! "$version" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    log_error "Invalid version format: $version"
    return 1
  fi
  
  local major="${BASH_REMATCH[1]}"
  local minor="${BASH_REMATCH[2]}"
  local patch="${BASH_REMATCH[3]}"
  
  case "$bump_type" in
    major)
      echo "v$((major + 1)).0.0"
      ;;
    minor)
      echo "v${major}.$((minor + 1)).0"
      ;;
    patch)
      echo "v${major}.${minor}.$((patch + 1))"
      ;;
    *)
      log_error "Unknown bump type: $bump_type"
      return 1
      ;;
  esac
}

## Bump version according to bump type
function bump_version() {
  local version="$1"
  local bump_type="$2"
  
  if [[ ! "$version" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    log_error "Invalid version format: $version"
    return 1
  fi
  
  local major="${BASH_REMATCH[1]}"
  local minor="${BASH_REMATCH[2]}"
  local patch="${BASH_REMATCH[3]}"
  
  case "$bump_type" in
    major)
      echo "v$((major + 1)).0.0"
      ;;
    minor)
      echo "v${major}.$((minor + 1)).0"
      ;;
    patch)
      echo "v${major}.${minor}.$((patch + 1))"
      ;;
    *)
      log_error "Unknown bump type: $bump_type"
      return 1
      ;;
  esac
}

## Setup test environment with sample data
function setup_test_mode() {
  local test_dir
  test_dir="$(mktemp -d)"
  
  log_info "Test mode enabled. Using temporary directory: $test_dir"
  
  ## Create sample base manifest (state at merge-base)
  cat > "$test_dir/base-manifest.yml" <<EOF
---
github/demo-hello: v0.0.2
github/go-build: v0.0.1
gitlab/demo/hello: v0.0.5
concourse/test-pipeline: v1.2.3
EOF
  
  ## Create current manifest with one manually bumped version
  #  demo-hello was manually bumped (v0.0.2 -> v0.0.3), so even if it changes, skip it
  cat > "$test_dir/current-manifest.yml" <<EOF
---
github/demo-hello: v0.0.3
github/go-build: v0.0.1
gitlab/demo/hello: v0.0.5
concourse/test-pipeline: v1.2.3
EOF
  
  ## Create sample changed files list
  #  Scenarios:
  #  - demo-hello.yml: changed but manually bumped (current v0.0.3 != base v0.0.2) -> SKIP
  #  - go-build.yml: changed and not bumped (current v0.0.1 == base v0.0.1) -> BUMP
  #  - gitlab/demo/hello.yml: changed and not bumped -> BUMP
  #  - README.md: changed but not a pipeline file -> SKIP
  #  - shared/scripts: changed but not a pipeline file -> SKIP
  cat > "$test_dir/changed-files.txt" <<EOF
.github/workflows/demo-hello.yml
.github/workflows/go-build.yml
gitlab/demo/hello.yml
README.md
shared/scripts/bash/go/go-build.sh
EOF
  
  log_info "Test manifest: $test_dir/current-manifest.yml"
  log_info "Test changed files: $test_dir/changed-files.txt"
  log_info "Test base manifest: $test_dir/base-manifest.yml"
  log_info ""
  log_info "Test scenarios:"
  log_info "  - github/demo-hello: Changed but manually bumped (v0.0.2->v0.0.3) -> Will skip"
  log_info "  - github/go-build: Changed and not bumped -> Will bump to v0.0.2"
  log_info "  - gitlab/demo/hello: Changed and not bumped -> Will bump to v0.0.6"
  log_info "  - README.md: Not a pipeline file -> Will skip"
  
  echo "$test_dir"
}

## Auto-detect changed files and base manifest when running locally
function auto_detect_changes() {
  ## Check if we're in a git repository
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_error "Not in a git repository. Cannot auto-detect changes."
    return 1
  fi
  
  ## Determine base branch (prefer origin/main, fallback to main)
  local base_branch="main"
  if git rev-parse --verify origin/main >/dev/null 2>&1; then
    base_branch="origin/main"
  elif git rev-parse --verify main >/dev/null 2>&1; then
    base_branch="main"
  else
    log_error "Cannot find main or origin/main branch"
    return 1
  fi
  
  log_info "Auto-detecting changes against $base_branch"
  
  ## Find merge-base
  local merge_base
  merge_base="$(git merge-base "$base_branch" HEAD 2>/dev/null)" || {
    log_error "Cannot find merge-base with $base_branch"
    return 1
  }
  
  log_verbose "Merge base: $merge_base"
  
  ## Create temporary files
  local tmp_changed_files
  local tmp_base_manifest
  tmp_changed_files="$(mktemp)"
  tmp_base_manifest="$(mktemp)"
  
  ## Get changed files (added, copied, modified, renamed, type changed)
  if ! git diff --name-only --diff-filter=ACMRT "$merge_base" HEAD > "$tmp_changed_files"; then
    rm -f "$tmp_changed_files" "$tmp_base_manifest"
    log_error "Failed to get list of changed files"
    return 1
  fi
  
  ## Get base manifest from merge-base
  if ! git show "${merge_base}:${MANIFEST}" > "$tmp_base_manifest" 2>/dev/null; then
    rm -f "$tmp_changed_files" "$tmp_base_manifest"
    log_error "Failed to retrieve base manifest from merge-base"
    return 1
  fi
  
  ## Set the file paths
  CHANGED_FILES_FILE="$tmp_changed_files"
  BASE_MANIFEST_FILE="$tmp_base_manifest"
  
  ## Track for cleanup
  auto_detect_cleanup_files="$tmp_changed_files $tmp_base_manifest"
  
  log_verbose "Changed files: $CHANGED_FILES_FILE"
  log_verbose "Base manifest: $BASE_MANIFEST_FILE"
  
  return 0
}

## Main execution starts here
########################################

## Handle test mode
test_cleanup_dir=""
auto_detect_cleanup_files=""

if [[ "$TEST_MODE" -eq 1 ]]; then
  test_cleanup_dir="$(setup_test_mode)"
  
  ## Set test environment
  CHANGED_FILES_FILE="$test_cleanup_dir/changed-files.txt"
  BASE_MANIFEST_FILE="$test_cleanup_dir/base-manifest.yml"
  MANIFEST="$test_cleanup_dir/current-manifest.yml"
  
  log_info "Test setup complete. Proceeding with test data"
  echo ""
fi

## Validate environment and files
[[ -f "$MANIFEST" ]] || { log_error "Manifest not found: $MANIFEST"; exit 1; }

changed_files_file="${CHANGED_FILES_FILE:-}"
base_manifest_file="${BASE_MANIFEST_FILE:-}"

## Auto-detect if not provided (and not in test mode)
if [[ "$TEST_MODE" -eq 0 ]] && { [[ -z "$changed_files_file" ]] || [[ -z "$base_manifest_file" ]]; }; then
  log_verbose "CHANGED_FILES_FILE or BASE_MANIFEST_FILE not provided, attempting auto-detection"
  if auto_detect_changes; then
    changed_files_file="$CHANGED_FILES_FILE"
    base_manifest_file="$BASE_MANIFEST_FILE"
  else
    log_error "Auto-detection failed. Please set CHANGED_FILES_FILE and BASE_MANIFEST_FILE."
    exit 1
  fi
fi

[[ -n "$changed_files_file" ]] || { log_error "CHANGED_FILES_FILE is required."; exit 1; }
[[ -n "$base_manifest_file" ]] || { log_error "BASE_MANIFEST_FILE is required."; exit 1; }
[[ -f "$changed_files_file" ]] || { log_error "Changed files list not found: $changed_files_file"; exit 1; }
[[ -f "$base_manifest_file" ]] || { log_error "Base manifest file not found: $base_manifest_file"; exit 1; }
[[ -s "$changed_files_file" ]] || { log_info "No changed files found."; exit 0; }

## Validate manifest files
validate_yaml "$MANIFEST" || { log_error "Current manifest validation failed"; exit 1; }
validate_yaml "$base_manifest_file" || { log_error "Base manifest validation failed"; exit 1; }

if [[ "$USE_YQ" -eq 1 ]]; then
  log_verbose "Using YAML manipulation: yq"
else
  log_verbose "Using YAML manipulation: awk"
fi
log_verbose "Bump type: $BUMP_TYPE"
if [[ "$DRY_RUN" -eq 1 ]]; then
  log_verbose "Dry run: yes"
else
  log_verbose "Dry run: no"
fi

## Create temporary files
tmp_pairs="$(mktemp)"

## Set up cleanup trap (combining test cleanup and auto-detect cleanup if needed)
cleanup_cmd="rm -f '$tmp_pairs' '${MANIFEST}.work' '${MANIFEST}.backup'"
[[ -n "$test_cleanup_dir" ]] && cleanup_cmd="$cleanup_cmd; rm -rf '$test_cleanup_dir'"
[[ -n "$auto_detect_cleanup_files" ]] && cleanup_cmd="$cleanup_cmd; rm -f $auto_detect_cleanup_files"
trap "$cleanup_cmd" EXIT

## Create backup and working copy
cp "$MANIFEST" "${MANIFEST}.backup"
cp "$MANIFEST" "${MANIFEST}.work"

declare -A SEEN_KEYS=()
declare -i change_count=0

## Process changed files
while IFS= read -r path; do
  [[ -z "$path" ]] && continue

  log_verbose "Processing file: $path"
  
  ## Check if file exists (skip non-existent files like deleted ones)
  if [[ ! -f "$path" ]] && [[ "$TEST_MODE" -eq 0 ]]; then
    log_verbose "  Skipped (file does not exist): $path"
    continue
  fi

  ## Convert path to manifest key
  key="$(path_to_key "$path")" || {
    log_verbose "  Skipped (not a tracked pipeline path): $path"
    continue
  }
  
  log_verbose "  Mapped to key: $key"

  ## Check if key is in IGNORE_KEYS
  for item in "${IGNORE_KEYS[@]}"; do
    if [[ "$key" == "$item" ]]; then
      log_verbose "  Skipped (in IGNORE_KEYS): $key"
      continue 2
    fi
  done

  ## Skip if we've already processed this key
  if [[ -n "${SEEN_KEYS[$key]:-}" ]]; then
    log_verbose "  Skipped (already processed): $key"
    continue
  fi
  SEEN_KEYS["$key"]=1

  ## Lookup values in base and current manifests
  base_value="$(lookup_value "$base_manifest_file" "$key")"
  current_value="$(lookup_value "${MANIFEST}.work" "$key")"

  log_verbose "  Base value: ${base_value:-<not set>}"
  log_verbose "  Current value: ${current_value:-<not set>}"

  ## Skip if key doesn't exist in either manifest
  [[ -z "$base_value" ]] && {
    log_verbose "  Skipped (not in base manifest): $key"
    continue
  }
  [[ -z "$current_value" ]] && {
    log_verbose "  Skipped (not in current manifest): $key"
    continue
  }

  ## Skip if value has been manually changed (different from base)
  if [[ "$current_value" != "$base_value" ]]; then
    log_verbose "  Skipped (manually modified, current != base): $key"
    continue
  fi

  ## Validate and bump version
  if [[ "$current_value" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    next="$(bump_version "$current_value" "$BUMP_TYPE")" || {
      log_error "Failed to bump version for $key"
      continue
    }
  else
    log_verbose "  Skipped (invalid version format): $key = $current_value"
    continue
  fi

  log_verbose "  Will bump: $current_value -> $next"
  
  ## Update working manifest
  if ! set_manifest_value "${MANIFEST}.work" "$key" "$next"; then
    log_error "Failed to update manifest for $key"
    continue
  fi
  
  printf '%s\t%s\t%s\n' "$key" "$current_value" "$next" >> "$tmp_pairs"
  change_count=$((change_count + 1))
done < "$changed_files_file"

## Check if any changes were made
if [[ ! -s "$tmp_pairs" ]]; then
  log_info "No releasable changes found."
  exit 0
fi

## Validate modified manifest
if ! validate_yaml "${MANIFEST}.work"; then
  log_error "Modified manifest validation failed. Rolling back changes."
  cp "${MANIFEST}.backup" "$MANIFEST"
  exit 1
fi

## Display summary
echo ""
echo "=========================================="
echo "  Version Bump Summary"
echo "=========================================="
echo "Bump type: $BUMP_TYPE"
echo "Changes: $change_count"
echo ""
printf "%-35s %-12s -> %-12s\n" "Pipeline" "Old Version" "New Version"
echo "------------------------------------------"
while IFS=$'\t' read -r key old new; do
  printf "%-35s %-12s -> %-12s\n" "$key" "$old" "$new"
done < "$tmp_pairs"
echo "=========================================="
echo ""

## Apply changes or show dry-run message
if [[ "$DRY_RUN" -eq 1 ]]; then
  log_info "DRY RUN: No changes written to $MANIFEST"
  exit 0
fi

## Write changes to manifest
mv "${MANIFEST}.work" "$MANIFEST"
log_info "Successfully updated $MANIFEST"

## Output changes for CI pipeline consumption
cat "$tmp_pairs"
