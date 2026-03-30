#!/usr/bin/env bash

#####################################################
# Ensure each pipeline in manifests/versions.yml    #
# has a git tag associated with it.                 #
#                                                   #
# Create missing tags locally, push if --push used. #
#####################################################

set -euo pipefail
IFS=$'\n\t'

MANIFEST="${MANIFEST:-manifests/versions.yml}"
REMOTE="${REMOTE:-origin}"
PUSH=0
DRY_RUN=0
VERBOSE=0

## Statistics tracking
declare -i tags_created=0
declare -i tags_pushed=0
declare -i tags_skipped_local=0
declare -i tags_skipped_remote=0
declare -i tags_total=0

function usage() {
  cat <<EOF

Usage: ${0##*/} [OPTIONS]

Synchronize git tags with all pipeline versions in manifests/versions.yml.
Creates missing tags locally and optionally pushes them to the remote.

Options:
  --manifest PATH   Manifest file to read (default: manifests/versions.yml)
  --remote NAME     Git remote to check/push (default: origin)
  --push            Push created tags to remote
  --dry-run         Show what would happen without making changes
  --verbose         Show detailed output for each pipeline
  -h, --help        Show this help message

Environment:
  MANIFEST          Same as --manifest
  REMOTE            Same as --remote

Examples:
  ${0##*/}                          # Create missing tags locally
  ${0##*/} --dry-run                # Preview what would be created
  ${0##*/} --push                   # Create and push missing tags
  ${0##*/} --push --verbose         # Detailed output
  ${0##*/} --remote upstream        # Use different remote

EOF
}

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

function log_error() {
  echo "[ERROR] $*" >&2
}

## Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)
      MANIFEST="${2:?missing value for --manifest}"
      shift 2
      ;;
    --remote)
      REMOTE="${2:?missing value for --remote}"
      shift 2
      ;;
    --push)
      PUSH=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown argument: $1"
      usage >&2
      exit 1
      ;;
  esac
done

## Validate manifest exists
[[ -f "$MANIFEST" ]] || { log_error "Manifest not found: $MANIFEST"; exit 1; }

## Validate git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  log_error "Must run inside a git repository"
  exit 1
fi

## Validate remote exists
if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
  log_error "Remote not found: $REMOTE"
  exit 1
fi

log_verbose "Manifest: $MANIFEST"
log_verbose "Remote: $REMOTE"
log_verbose "Push: $([ "$PUSH" -eq 1 ] && echo 'yes' || echo 'no')"
log_verbose "Dry run: $([ "$DRY_RUN" -eq 1 ] && echo 'yes' || echo 'no')"

log_verbose "Manifest: $MANIFEST"
log_verbose "Remote: $REMOTE"
log_verbose "Push: $([ "$PUSH" -eq 1 ] && echo 'yes' || echo 'no')"
log_verbose "Dry run: $([ "$DRY_RUN" -eq 1 ] && echo 'yes' || echo 'no')"

## Fetch remote tags
log_info "Fetching tags from $REMOTE..."
remote_tags="$(mktemp)"
trap 'rm -f "$remote_tags"' EXIT

if ! git ls-remote --tags "$REMOTE" > "$remote_tags"; then
  log_error "Failed to fetch tags from $REMOTE"
  exit 1
fi

log_verbose "Fetched remote tags successfully"

function remote_has_tag() {
  ## Check if remote has a tag
  local tag="$1"
  grep -qE "[[:space:]]refs/tags/${tag}(\^\{\})?$" "$remote_tags"
}

function local_has_tag() {
  ## Check if a local tag exists
  local tag="$1"
  git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1
}

function create_tag() {
  ## Create pipeline version tag if it doesn't exist
  local tag="$1"
  local message="$2"
  local local_exists=0
  local remote_exists=0

  tags_total=$((tags_total + 1))
  
  log_verbose "Processing tag: $tag"

  ## Check local tag
  if local_has_tag "$tag"; then
    local_exists=1
    log_verbose "  Local tag exists"
  fi

  ## Check remote tag
  if remote_has_tag "$tag"; then
    remote_exists=1
    log_verbose "  Remote tag exists"
  fi

  ## Create local tag if needed
  if [[ "$local_exists" -eq 0 && "$remote_exists" -eq 0 ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_info "Would create tag: $tag"
      tags_created=$((tags_created + 1))
      return 0
    fi

    if git tag -a "$tag" -m "$message"; then
      log_info "Created tag: $tag"
      local_exists=1
      tags_created=$((tags_created + 1))
    else
      log_error "Failed to create tag: $tag"
      return 1
    fi
  elif [[ "$local_exists" -eq 1 && "$remote_exists" -eq 1 ]]; then
    log_verbose "  Skipped (already synchronized)"
    tags_skipped_remote=$((tags_skipped_remote + 1))
  elif [[ "$local_exists" -eq 1 ]]; then
    log_verbose "  Skipped (exists locally)"
  elif [[ "$remote_exists" -eq 1 ]]; then
    log_verbose "  Skipped (exists on remote)"
    tags_skipped_remote=$((tags_skipped_remote + 1))
  fi

  ## Push tag if requested and needed
  if [[ "$PUSH" -eq 1 && "$remote_exists" -eq 0 && "$local_exists" -eq 1 ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_info "Would push tag: $tag"
      tags_pushed=$((tags_pushed + 1))
      return 0
    fi

    if git push "$REMOTE" "$tag"; then
      log_info "Pushed tag: $tag"
      tags_pushed=$((tags_pushed + 1))
    else
      log_error "Failed to push tag: $tag"
      return 1
    fi
  fi
  
  return 0
}

## Process manifest
log_info "Processing manifest: $MANIFEST"
echo ""

## Count lines for processing
pipeline_count=$(grep -cE '^[^#[:space:]][^:]+: v[0-9]+\.[0-9]+\.[0-9]+$' "$MANIFEST" || true)
log_verbose "Found $pipeline_count pipeline(s) to process"

if [[ "$pipeline_count" -eq 0 ]]; then
  log_info "No pipelines found in manifest with valid version tags"
  exit 0
fi

## Read manifest file and process each pipeline version
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" != *:* ]] && continue

  key="${line%%:*}"
  version="${line#*: }"

  ## Skip if version doesn't match semver format
  [[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue

  tag="${key}/${version}"
  create_tag "$tag" "$key $version"
done < <(grep -E '^[^#[:space:]][^:]+: v[0-9]+\.[0-9]+\.[0-9]+$' "$MANIFEST" || true)

## Display summary
echo ""
echo "=========================================="
echo "  Tag Synchronization Summary"
echo "=========================================="
echo "Total pipelines:    $tags_total"
echo "Tags created:       $tags_created"
[[ "$PUSH" -eq 1 ]] && echo "Tags pushed:        $tags_pushed"
echo "Already synced:     $tags_skipped_remote"
echo "Dry run:            $([ "$DRY_RUN" -eq 1 ] && echo 'Yes' || echo 'No')"
echo "=========================================="
echo ""

if [[ "$DRY_RUN" -eq 1 ]]; then
  log_info "DRY RUN: No changes were made"
else
  log_info "Synchronization complete"
fi
