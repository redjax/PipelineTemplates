#!/usr/bin/env bash
set -euo pipefail

##############################################
# Create GitHub Releases for component tags. #
#                                            #
# Tag format:                                #
#   <prefix>/<component>/v<version>          #
##############################################

DRY_RUN="false"
BASE_REF="${BASE_REF:-HEAD}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(realpath -m "$SCRIPT_DIR/../../..")"

function usage() {
  cat <<EOF
Usage: ${0} [OPTIONS]

Options:
  -h, --help    Print help menu
  --dry-run     Show actions without executing them
EOF
}

function normalize() {
  echo "${1#./}"
}

function tag_to_release_title() {
  local tag="$1"
  echo "${tag}"
}

function tag_has_release() {
  local tag="$1"

  gh release view "$tag" >/dev/null 2>&1
}

function create_release() {
  local tag="$1"

  gh release create "$tag" \
    --repo "$GITHUB_REPOSITORY" \
    --title "$(tag_to_release_title "$tag")" \
    --generate-notes
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run)
    DRY_RUN="true"
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "[ERROR] Unknown arg: $1" >&2
    exit 1
    ;;
  esac
done

cd "$REPO_ROOT"

mapfile -t TAGS < <(
  git tag --merged "$BASE_REF" |
    grep -E '^(gh|gl|woodpecker|concourse)/.+/v[0-9]+\.[0-9]+\.[0-9]+$' || true
)

if [[ ${#TAGS[@]} -eq 0 ]]; then
  echo "[INFO] No component tags found."
  exit 0
fi

for tag in "${TAGS[@]}"; do
  if tag_has_release "$tag"; then
    echo "[SKIP] Release exists: $tag"
    continue
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] gh release create \"$tag\" --repo \"$GITHUB_REPOSITORY\" --title \"$tag\" --generate-notes"
  else
    echo "[INFO] Creating release: $tag"
    create_release "$tag"
  fi
done
