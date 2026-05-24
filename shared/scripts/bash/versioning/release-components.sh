#!/usr/bin/env bash
set -euo pipefail

######################################################################
# Component release orchestrator script.                             #
#                                                                    #
# Detects changed components, bumps versions, tags releases, and     #
# optionally commits/pushes the result.                              #
#                                                                    #
# A component is any directory containing a .bumpversion.toml file.  #
#                                                                    #
# Version bump rules:                                                #
#   Breaking change / feat! -> major                                 #
#   feat                    -> minor                                 #
#   everything else         -> patch                                 #
######################################################################

BASE_REF="${BASE_REF:-origin/main}"
DRY_RUN="false"
PUSH="${PUSH:-false}"
COMMIT="${COMMIT:-true}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(realpath -m "$SCRIPT_DIR/../../../..")"

function usage() {
  cat <<EOF
Usage: ${0} [OPTIONS]

Options:
  -h, --help    Print help menu
  --dry-run     Describe actions without taking them
  --no-push     Create tags but don't push to remote
  --no-commit   Create tags but don't commit
EOF
}

## Parse CLI args
while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run)
    DRY_RUN="true"
    shift
    ;;
  --no-push)
    PUSH="false"
    shift
    ;;
  --no-commit)
    COMMIT="false"
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

## Normalize path
function normalize() {
  echo "${1#./}"
}

function resolve_prefix() {
  local component="$1"

  case "$component" in
  .github/*)
    echo "gh"
    ;;
  gitlab/*)
    echo "gl"
    ;;
  woodpecker/*)
    echo "woodpecker"
    ;;
  concourse/*)
    echo "concourse"
    ;;
  *)
    echo "unknown"
    ;;
  esac
}

## Ensure minimum released version is 0.0.1
function normalize_release_version() {
  local version="$1"

  if [[ "$version" == "0.0.0" ]]; then
    echo "0.0.1"
  else
    echo "$version"
  fi
}

function get_bump_type() {
  local component="$1"
  local component_name prefix last_tag range commits

  component="$(normalize "$component")"
  component_name="$(basename "$component")"
  prefix="$(resolve_prefix "$component")"

  last_tag="$(
    git tag --list "${prefix}/${component_name}/v*" \
      --sort=-v:refname |
      head -n 1
  )"

  if [[ -z "$last_tag" ]]; then
    range="${BASE_REF}..HEAD"
  else
    range="${last_tag}..HEAD"
  fi

  commits="$(
    git log --format=%s "${range}" -- "$component" || true
  )"

  if [[ -z "$commits" ]]; then
    echo ""
    return
  fi

  if echo "$commits" | grep -Eq 'BREAKING CHANGE|!:'; then
    echo "major"
    return
  fi

  if echo "$commits" | grep -Eq '^feat(\(.+\))?:'; then
    echo "minor"
    return
  fi

  echo "patch"
}

cd "$REPO_ROOT"

mapfile -t COMPONENTS < <(
  find . -type f -name ".bumpversion.toml" -exec dirname {} + | sort -u
)

if [[ ${#COMPONENTS[@]} -eq 0 ]]; then
  echo "[INFO] No bumpable components found."
  exit 0
fi

CHANGED_COMPONENTS=()
for c in "${COMPONENTS[@]}"; do
  c="$(normalize "$c")"
  if ! git diff --quiet "${BASE_REF}...HEAD" -- "$c"; then
    CHANGED_COMPONENTS+=("$c")
  fi
done

if [[ ${#CHANGED_COMPONENTS[@]} -eq 0 ]]; then
  echo "[INFO] No changed components."
  exit 0
fi

echo "[INFO] Changed components:"
printf ' - %s\n' "${CHANGED_COMPONENTS[@]}"

RELEASED_COMPONENTS=()
VERSION_FILES=()

for component in "${CHANGED_COMPONENTS[@]}"; do
  bump_type="$(get_bump_type "$component")"

  if [[ -z "$bump_type" ]]; then
    echo "[INFO] No commits found for $component; skipping."
    continue
  fi

  echo "[INFO] Bumping $component -> $bump_type"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] $SCRIPT_DIR/bump-component.sh --component-path $component --bump-type $bump_type"
  else
    "$SCRIPT_DIR/bump-component.sh" \
      --component-path "$component" \
      --bump-type "$bump_type"
  fi

  RELEASED_COMPONENTS+=("$component")
  VERSION_FILES+=("$component/VERSION")
done

if [[ ${#RELEASED_COMPONENTS[@]} -eq 0 ]]; then
  echo "[INFO] No components were released."
  exit 0
fi

if [[ "$COMMIT" == "true" && "$DRY_RUN" != "true" ]]; then
  if ! git diff --quiet; then
    git add "${VERSION_FILES[@]}"
    git commit -m "chore(release): bump component versions"
  else
    echo "[INFO] No version changes to commit."
  fi
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY RUN] Would tag released components:"
fi

for component in "${RELEASED_COMPONENTS[@]}"; do
  component="$(normalize "$component")"
  component_name="$(basename "$component")"
  prefix="$(resolve_prefix "$component")"
  version="$(cat "$component/VERSION")"
  version="$(normalize_release_version "$version")"
  tag="${prefix}/${component_name}/v${version}"

  if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    echo "[SKIP] Tag exists: $tag"
    continue
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] git tag -a $tag -m $tag"
  else
    echo "[INFO] Tagging $tag"
    git tag -a "$tag" -m "$tag"
  fi
done

if [[ "$PUSH" == "true" && "$DRY_RUN" != "true" ]]; then
  git push origin HEAD --follow-tags
fi
