#!/usr/bin/env bash
set -euo pipefail

###############################################
# Create git tags for versioned components.   #
#                                             #
# Tag format:                                 #
#   <prefix>/<component>/v<version>           #
#                                             #
# Prefix derived from directory:              #
#   .github/      --> gh                      #
#   .forgejo/     --> fj                      #
#   gitlab/       --> gl                      #
#   woodpecker/   --> woodpecker              #
#   concourse/    --> concourse               #
###############################################

BASE_DIR="${BASE_DIR:-.}"
DRY_RUN="false"
PUSH="${PUSH:-false}"
BASE_REF="${BASE_REF:-}"

source "$(dirname "$0")/../_util/git-tag-lib.sh"

function resolve_prefix() {
  case "$1" in
  .github/*) echo "gh" ;;
  .forgejo/*) echo "fj" ;;
  gitlab/*) echo "gl" ;;
  woodpecker/*) echo "woodpecker" ;;
  concourse/*) echo "concourse" ;;
  *) echo "unknown" ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run)
    DRY_RUN="true"
    shift
    ;;
  --push)
    PUSH="true"
    shift
    ;;
  *)
    echo "[ERROR] Unknown arg: $1" >&2
    exit 1
    ;;
  esac
done

cd "$BASE_DIR"

git fetch origin main >/dev/null 2>&1 || true

if [[ -z "$BASE_REF" ]]; then
  BASE_REF="$(git merge-base HEAD origin/main)"
fi

fetch_git_tags

mapfile -t COMPONENTS < <(
  find . -type f -name "VERSION" -exec dirname {} + | sort -u
)

CREATED_TAGS=()

for component in "${COMPONENTS[@]}"; do
  component="${component#./}"

  version_file="$component/VERSION"
  [[ -f "$version_file" ]] || continue

  version="$(tr -d '[:space:]' <"$version_file")"

  component_name="${component##*/}"
  prefix="$(resolve_prefix "$component")"

  tag="${prefix}/${component_name}/v${version}"

  if [[ "$version" == "0.0.0" ]]; then
    echo "[SKIP] unreleased: $component"
    continue
  fi

  if tag_exists "$tag"; then
    echo "[SKIP] $tag"
    continue
  fi

  echo "[INFO] creating tag: $tag"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] git tag -a $tag -m $tag"
    continue
  fi

  git tag -a "$tag" -m "$tag"
  CREATED_TAGS+=("$tag")
done

if [[ "$PUSH" == "true" && "$DRY_RUN" != "true" ]]; then
  if [[ ${#CREATED_TAGS[@]} -eq 0 ]]; then
    echo "[INFO] No new tags to push."
    exit 0
  fi

  git push origin "${CREATED_TAGS[@]}"
fi
