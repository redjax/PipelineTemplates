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
#   gitlab/       --> gl                      #
#   woodpecker/   --> woodpecker              #
#   concourse/    --> concourse               #
###############################################

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_DIR}/../_util/git-tag-lib.sh"

BASE_DIR="${BASE_DIR:-.}"
DRY_RUN="false"
PUSH="${PUSH:-false}"

function usage() {
  cat <<EOF
Usage: ${0} [OPTIONS]

Options:
  --dry-run
  --push
  -h, --help
EOF
}

resolve_prefix() {
  case "$1" in
  .github/*) echo "gh" ;;
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

cd "$BASE_DIR"

fetch_git_tags

mapfile -t COMPONENTS < <(
  find . -type f -name "VERSION" -exec dirname {} + | sort -u
)

CREATED=()

for component in "${COMPONENTS[@]}"; do
  component="${component#./}"

  version="$(tr -d '[:space:]' <"$component/VERSION")"

  ## Do not create v0.0.0 tags
  if [[ "$version" == "0.0.0" ]]; then
    echo "[SKIP] $component (unreleased)"
    continue
  fi

  component_name="${component##*/}"
  prefix="$(resolve_prefix "$component")"

  tag="${prefix}/${component_name}/v${version}"

  if tag_exists "$tag"; then
    continue
  fi

  echo "[INFO] tag: $tag"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] git tag -a $tag -m $tag"
    continue
  fi

  git tag -a "$tag" -m "$tag"
  CREATED+=("$tag")
done

if [[ "$PUSH" == "true" && "$DRY_RUN" != "true" ]]; then
  git push origin "${CREATED[@]}"
fi
