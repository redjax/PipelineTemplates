#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

MANIFEST="${MANIFEST:-manifests/versions.yml}"
TEMPLATE="${TEMPLATE:-}"
VERSION="${VERSION:-}"
DO_TAG=0
DO_PUSH=0
DRY_RUN=0
VERBOSE=0
REMOTE="${REMOTE:-origin}"
USE_YQ=0

## Detect if yq is available
if command -v yq >/dev/null 2>&1; then
  USE_YQ=1
fi

function usage() {
  cat <<EOF

Usage: ${0##*/} [OPTIONS]

Manually set a specific pipeline version, bypassing the automated release workflow.
Useful for emergency hotfixes, initial versions, or skipping version numbers.

Options:
  --template NAME     Pipeline key (e.g., github/demo-hello, gitlab/test)
  --version VERSION   Target version (e.g., v1.0.0, v2.3.4)
  --tag               Create a git tag for this release
  --push              Push the tag to remote (requires --tag)
  --remote NAME       Git remote to push to (default: origin)
  --dry-run           Show what would happen without making changes
  --verbose           Show detailed output
  -h, --help          Show this help message

Environment variables:
  TEMPLATE            Same as --template
  VERSION             Same as --version
  MANIFEST            Path to versions.yml (default: manifests/versions.yml)
  REMOTE              Same as --remote

Examples:
  ${0##*/} --template github/demo-hello --version v0.0.1
  ${0##*/} --template github/demo-hello --version v0.0.1 --tag
  ${0##*/} --template github/demo-hello --version v1.0.0 --tag --push
  ${0##*/} --template gitlab/new-pipeline --version v0.1.0 --tag --dry-run

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

## Validate version format
function validate_version() {
  local version="$1"
  if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid version format: $version (must be vX.Y.Z)"
    return 1
  fi
  return 0
}

## Set a value in the manifest file (uses yq or awk)
function set_manifest_value() {
  local file="$1"
  local key="$2"
  local value="$3"

  if [[ "$USE_YQ" -eq 1 ]]; then
    if ! yq eval ".\"${key}\" = \"${value}\"" -i "$file"; then
      return 1
    fi
  else
    ## AWK: update existing key or append new key
    local tmp
    tmp="$(mktemp)"
    awk -v key="$key" -v val="$value" '
      BEGIN { found = 0 }
      $1 == key ":" {
        print key ": " val
        found = 1
        next
      }
      { print }
      END {
        if (!found) print key ": " val
      }
    ' "$file" > "$tmp"
    
    if ! mv "$tmp" "$file"; then
      rm -f "$tmp"
      return 1
    fi
  fi
  
  return 0
}

## Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --template)
      TEMPLATE="${2:?missing value for --template}"
      shift 2
      ;;
    --version)
      VERSION="${2:?missing value for --version}"
      shift 2
      ;;
    --tag)
      DO_TAG=1
      shift
      ;;
    --push)
      DO_PUSH=1
      shift
      ;;
    --remote)
      REMOTE="${2:?missing value for --remote}"
      shift 2
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

## Validate required arguments
if [[ -z "$TEMPLATE" || -z "$VERSION" ]]; then
  log_error "--template and --version are required"
  usage >&2
  exit 1
fi

## Validate version format
validate_version "$VERSION" || exit 1

## Validate manifest exists
[[ -f "$MANIFEST" ]] || { log_error "Manifest not found: $MANIFEST"; exit 1; }

## Validate git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  log_error "Not in a git repository"
  exit 1
fi

## Build tag name
TAG="${TEMPLATE}/${VERSION}"

log_verbose "Template: $TEMPLATE"
log_verbose "Version: $VERSION"
log_verbose "Tag: $TAG"
log_verbose "Manifest: $MANIFEST"
log_verbose "Using YAML manipulation: $([ "$USE_YQ" -eq 1 ] && echo 'yq' || echo 'awk')"

## Check if tag already exists
if [[ "$DO_TAG" -eq 1 ]]; then
  if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null 2>&1; then
    log_error "Tag already exists: ${TAG}"
    log_info "Use 'git tag -d ${TAG}' to delete it first if you want to recreate it"
    exit 1
  fi
  log_verbose "Tag does not exist yet: $TAG"
fi

## Validate remote if pushing
if [[ "$DO_PUSH" -eq 1 ]]; then
  if [[ "$DO_TAG" -ne 1 ]]; then
    log_error "--push requires --tag"
    exit 1
  fi
  
  if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
    log_error "Remote not found: $REMOTE"
    exit 1
  fi
  log_verbose "Remote exists: $REMOTE"
fi

## Display summary
echo ""
echo "=========================================="
echo "  Manual Release Summary"
echo "=========================================="
echo "Pipeline:  $TEMPLATE"
echo "Version:   $VERSION"
echo "Tag:       $([ "$DO_TAG" -eq 1 ] && echo "Yes ($TAG)" || echo "No")"
echo "Push:      $([ "$DO_PUSH" -eq 1 ] && echo "Yes (to $REMOTE)" || echo "No")"
echo "Dry run:   $([ "$DRY_RUN" -eq 1 ] && echo "Yes" || echo "No")"
echo "=========================================="
echo ""

if [[ "$DRY_RUN" -eq 1 ]]; then
  log_info "DRY RUN: No changes will be made"
  exit 0
fi

## Create backup
tmp_backup="$(mktemp)"
trap 'rm -f "$tmp_backup"' EXIT
cp "$MANIFEST" "$tmp_backup"

log_verbose "Created backup: $tmp_backup"

## Update manifest
log_info "Updating $MANIFEST"
if ! set_manifest_value "$MANIFEST" "$TEMPLATE" "$VERSION"; then
  log_error "Failed to update manifest"
  cp "$tmp_backup" "$MANIFEST"
  exit 1
fi

log_info "Successfully updated manifest"

## Commit changes
log_info "Committing changes"
if ! git add "$MANIFEST"; then
  log_error "Failed to stage manifest"
  cp "$tmp_backup" "$MANIFEST"
  exit 1
fi

commit_msg="Release ${TEMPLATE} ${VERSION}"
if ! git commit -m "$commit_msg"; then
  log_error "Failed to commit changes"
  git restore --staged "$MANIFEST"
  cp "$tmp_backup" "$MANIFEST"
  exit 1
fi

log_info "Committed: $commit_msg"

## Create tag if requested
if [[ "$DO_TAG" -eq 1 ]]; then
  log_info "Creating tag: $TAG"
  if ! git tag -a "$TAG" -m "${TEMPLATE} ${VERSION}"; then
    log_error "Failed to create tag"
    log_info "Changes were committed but tag creation failed"
    exit 1
  fi
  log_info "Successfully created tag: $TAG"
  
  ## Push tag if requested
  if [[ "$DO_PUSH" -eq 1 ]]; then
    log_info "Pushing tag to $REMOTE"
    if ! git push "$REMOTE" "$TAG"; then
      log_error "Failed to push tag to $REMOTE"
      log_info "Tag was created locally but push failed"
      exit 1
    fi
    log_info "Successfully pushed tag to $REMOTE"
  fi
fi

echo ""
echo "=========================================="
echo "  Release Complete"
echo "=========================================="
echo "✓ Updated manifest: $MANIFEST"
echo "✓ Committed changes"
[[ "$DO_TAG" -eq 1 ]] && echo "✓ Created tag: $TAG"
[[ "$DO_PUSH" -eq 1 ]] && echo "✓ Pushed tag to: $REMOTE"
echo "=========================================="
echo ""

log_info "Done!"
