#!/usr/bin/env bash
set -euo pipefail

########################################################
# Component release orchestrator script.               #
#                                                      #
# Orchestrates the version bump, git tag, and release  #
# of changed CI components.                            #
#                                                      #
# Can be run locally or in a pipeline.                 #
########################################################

BASE_REF="${BASE_REF:-origin/main}"
DRY_RUN="false"
PUSH="${PUSH:-false}"
COMMIT="${COMMIT:-true}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath -m "$SCRIPT_DIR/../..")"

function usage() {
  cat <<EOF
Usage ${0} [OPTIONS]

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

## Resolve bump type from commits
function get_bump_type() {
  local component="$1"

  local commits
  commits="$(git log --format=%s "${BASE_REF}..HEAD" -- "$component")"

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

## Discover components
mapfile -t COMPONENTS < <(
  find . -type f -name ".bumpversion.toml" \
    -exec dirname {} + |
    sort -u
)

## Detect changed components
CHANGED_COMPONENTS=()

for c in "${COMPONENTS[@]}"; do
  c="$(normalize "$c")"

  if ! git diff --quiet "${BASE_REF}...HEAD" -- "$c"; then
    CHANGED_COMPONENTS+=("$c")
  fi
done

if [[ ${#CHANGED_COMPONENTS[@]} -eq 0 ]]; then
  echo "[INFO] No changed components"
  exit 0
fi

echo "[INFO] Changed components:"
printf ' - %s\n' "${CHANGED_COMPONENTS[@]}"

## Bump component versions
for component in "${CHANGED_COMPONENTS[@]}"; do

  bump_type="$(get_bump_type "$component")"

  echo "[INFO] Bumping $component -> $bump_type"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] bump-component.sh --component-path $component --bump-type $bump_type"
  else
    "$SCRIPT_DIR/bump-component.sh" \
      --component-path "$component" \
      --bump-type "$bump_type"
  fi

done

## Commit version changes
if [[ "$COMMIT" == "true" && "$DRY_RUN" != "true" ]]; then
  if ! git diff --quiet; then
    git add .
    git commit -m "chore(release): bump component versions"
  fi
fi

## Create component git tags
if [[ "$DRY_RUN" == "true" ]]; then
  "$SCRIPT_DIR/git-tag-components.sh" --dry-run
else
  "$SCRIPT_DIR/git-tag-components.sh"
fi

## Push changes
if [[ "$PUSH" == "true" && "$DRY_RUN" != "true" ]]; then
  git push origin HEAD --follow-tags
fi
