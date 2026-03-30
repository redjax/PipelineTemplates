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

function usage() {
  cat <<EOF
Usage: ${0##*/} [--manifest PATH] [--remote NAME] [--push] [--dry-run]

Options:
  --manifest PATH   Manifest file to read. Default: manifests/versions.yml
  --remote NAME     Git remote to check/push. Default: origin
  --push            Push created tags to remote
  --dry-run         Show what would happen, but do not create or push tags
  -h, --help        Show help
EOF
}

## Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)
      MANIFEST="$2"
      shift 2
      ;;
    --remote)
      REMOTE="$2"
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
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

[[ -f "$MANIFEST" ]] || { echo "Manifest not found: $MANIFEST" >&2; exit 1; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "Must run inside a git repository." >&2
  exit 1
}

## Output tags on remote to local tmp file
remote_tags="$(mktemp)"
trap 'rm -f "$remote_tags"' EXIT

git ls-remote --tags "$REMOTE" > "$remote_tags"

function remote_has_tag() {
  ## Check if remote origin has a tag
  local tag="$1"
  grep -qE "[[:space:]]refs/tags/${tag}(\^\{\})?$" "$remote_tags"
}

function local_has_tag() {
  ## Check if a local tag exists
  local tag="$1"
  git rev-parse -q --verify "refs/tags/$tag" >/dev/null
}

function create_tag() {
  ## Create pipeline version tag if it doesn't exist
  local tag="$1"
  local message="$2"
  local local_exists=0
  local remote_exists=0

  ## Local tag check
  if local_has_tag "$tag"; then
    local_exists=1
    echo "Local tag exists: $tag"
  fi

  ## Remote tag check
  if remote_has_tag "$tag"; then
    remote_exists=1
    echo "Remote tag exists: $tag"
  fi

  ## Evaluate & create local tag
  if [[ "$local_exists" -eq 0 && "$remote_exists" -eq 0 ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "Would create tag: $tag"
      return 0
    fi

    git tag -a "$tag" -m "$message"
    local_exists=1

    echo "Created tag: $tag"
  fi

  ## If --push, ensure local tags exists on the remote
  if [[ "$PUSH" -eq 1 && "$remote_exists" -eq 0 && "$local_exists" -eq 1 ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "Would push tag: $tag"
      return 0
    fi

    git push "$REMOTE" "$tag"
    echo "Pushed tag: $tag"
  fi
}

## Read manifest file lines into function,
#  check if version tag exists for each version.
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" != *:* ]] && continue


  key="${line%%:*}"
  version="${line#*: }"


  [[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue


  tag="${key}/${version}"
  create_tag "$tag" "$key $version"
done < <(grep -E '^[^#[:space:]][^:]+: v[0-9]+\.[0-9]+\.[0-9]+$' "$MANIFEST")
