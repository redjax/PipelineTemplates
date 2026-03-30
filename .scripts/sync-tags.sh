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


created_tags=()


function usage() {
  cat <<EOF
Usage: ${0##*/} [--manifest PATH] [--remote NAME] [--push]


Options:
  --manifest PATH   Manifest file to read. Default: manifests/versions.yml
  --remote NAME     Git remote to check/push. Default: origin
  --push            Push created tags to remote
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


function create_tag() {
  ## Create pipeline version tag if it doesn't exist
  local tag="$1"
  local message="$2"
  local local_exists=0
  local remote_exists=0


  ## Check if tag exists locally
  if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    local_exists=1
    echo "Local tag exists: $tag"
  fi


  ## Check if tag exists on remote
  if grep -qE "[[:space:]]refs/tags/${tag}(\^\{\})?$" "$remote_tags"; then
    remote_exists=1
    echo "Remote tag exists: $tag"
  fi


  ## Create tag if it doesn't exist locally or on the remote
  if [[ "$local_exists" -eq 0 && "$remote_exists" -eq 0 ]]; then
    git tag -a "$tag" -m "$message"
    local_exists=1
    created_tags+=("$tag")
    echo "Created tag: $tag"
  fi


  ## Track tags created earlier in a dry run so they can be pushed later
  if [[ "$local_exists" -eq 1 && "$remote_exists" -eq 0 ]]; then
    created_tags+=("$tag")
  fi


  ## Push tag if --push was used and remote doesn't have it yet
  if [[ "$PUSH" -eq 1 && "$remote_exists" -eq 0 && "$local_exists" -eq 1 ]]; then
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