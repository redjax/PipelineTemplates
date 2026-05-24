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

BASE_DIR="${BASE_DIR:-.}"
DRY_RUN="false"

function usage() {
  cat <<EOF
Usage: ${0} [OPTIONS]

Options:
  -h, --help     Print help menu
  --dry-run      Show actions without executing them
EOF
}

function tag_exists_locally() {
  git rev-parse -q --verify "refs/tags/$1" >/dev/null
}

function tag_exists_remotely() {
  git ls-remote --tags origin "refs/tags/$1" | grep -q "$1" || true
}

function tag_exists() {
  local tag="$1"

  git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1 && return 0

  git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1
}

## Resolve platform prefix from component path
function resolve_prefix() {
  local component="$1"

  case "$component" in
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
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "[ERROR] Unknown argument: $1" >&2
    exit 1
    ;;
  esac
done

cd "$BASE_DIR"

## Find all components (directories with VERSION file)
mapfile -t COMPONENTS < <(
  find . -type f -name "VERSION" \
    -exec dirname {} + |
    sort -u
)

## Fetch all tags
git fetch --tags --force

## Tag each component if needed
for component in "${COMPONENTS[@]}"; do
  ## Strip ./ from component path string
  component="${component#./}"
  version_file="${component}/VERSION"

  [[ -f "$version_file" ]] || continue

  version="$(cat "$version_file")"

  component_name="$(basename "$component")"
  prefix="$(resolve_prefix "$component")"

  tag="${prefix}/${component_name}/v${version}"

  if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    echo "[SKIP] Tag exists: $tag"
    continue
  fi

  echo "[INFO] Tagging $tag"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] git tag -a $tag -m $tag"
  else
    git tag -a "$tag" -m "$tag"
  fi
done
