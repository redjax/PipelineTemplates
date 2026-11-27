#!/usr/bin/env bash
set -euo pipefail

######################################################################
# Component release orchestrator script.                             #
#                                                                    #
# Detects changed components and delegates version bumps to          #
# bump-component.sh.                                                 #
#                                                                    #
# A component is any directory containing a .bumpversion.toml file.  #
#                                                                    #
# Version bump rules:                                                #
#   Breaking change / feat! -> major                                 #
#   feat                    -> minor                                 #
#   everything else         -> patch                                 #
#                                                                    #
# Components at 0.0.0 are always bumped (to 0.0.1).                  #
# Release bump commits are ignored to avoid bump loops.              #
######################################################################

BASE_REF="${BASE_REF:-}"
DRY_RUN="${DRY_RUN:-false}"
OUTPUT_FILE="${OUTPUT_FILE:-}"
RELEASE_COMMIT_PATTERN='^chore\(release\): bump component versions'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(realpath -m "$SCRIPT_DIR/../../../..")"
BUMP_COMPONENT_SCRIPT="${SCRIPT_DIR}/bump-component.sh"

function usage() {
  cat <<EOF
Usage: ${0} [OPTIONS]


Options:
  --dry-run
  --output-file <path>
  -h, --help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run)
    DRY_RUN="true"
    shift
    ;;
  --output-file)
    OUTPUT_FILE="$2"
    shift 2
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

git fetch origin main >/dev/null 2>&1 || true

if [[ -z "$BASE_REF" ]]; then
  BASE_REF="$(git merge-base HEAD origin/main)"
fi

## Commit subjects touching a component, excluding merges and release bump commits
function component_commits() {
  local component="$1"

  git log --no-merges --format=%s "${BASE_REF}..HEAD" -- "$component" |
    grep -Ev "$RELEASE_COMMIT_PATTERN" || true
}

## Determine the bump type from commit subjects (empty = nothing to release)
function determine_bump_type() {
  local component="$1"
  local commits

  commits="$(component_commits "$component")"

  if [[ -z "$commits" ]]; then
    echo ""
  elif echo "$commits" | grep -Eq 'BREAKING CHANGE|!:'; then
    echo "major"
  elif echo "$commits" | grep -Eq '^feat(\(.+\))?:'; then
    echo "minor"
  else
    echo "patch"
  fi
}

mapfile -t COMPONENTS < <(
  find . -type f -name ".bumpversion.toml" -not -path './.git/*' -exec dirname {} + | sort -u
)

## Map of component -> bump type for everything that needs a release
declare -A BUMPS=()
CHANGED_COMPONENTS=()

for c in "${COMPONENTS[@]}"; do
  c="${c#./}"
  version_file="$c/VERSION"

  if [[ ! -f "$version_file" ]]; then
    echo "[WARN] $c has no VERSION file; skipping." >&2
    continue
  fi

  current_version="$(tr -d '[:space:]' <"$version_file")"

  ## First release: always bump 0.0.0 -> 0.0.1
  if [[ "$current_version" == "0.0.0" ]]; then
    BUMPS["$c"]="patch"
    CHANGED_COMPONENTS+=("$c")
    continue
  fi

  ## VERSION already changed in this range: already bumped, skip
  if git diff --name-only "${BASE_REF}..HEAD" -- "$version_file" | grep -q .; then
    echo "[INFO] $c VERSION already changed in this range; skipping."
    continue
  fi

  bump="$(determine_bump_type "$c")"
  if [[ -n "$bump" ]]; then
    BUMPS["$c"]="$bump"
    CHANGED_COMPONENTS+=("$c")
  fi
done

if [[ ${#CHANGED_COMPONENTS[@]} -eq 0 ]]; then
  echo "[INFO] No changed components."
  if [[ -n "$OUTPUT_FILE" ]]; then
    : >"$OUTPUT_FILE"
  fi
  exit 0
fi

echo "[INFO] Changed components:"
printf ' - %s\n' "${CHANGED_COMPONENTS[@]}"

if [[ -n "$OUTPUT_FILE" ]]; then
  printf '%s\n' "${CHANGED_COMPONENTS[@]}" >"$OUTPUT_FILE"
fi

for component in "${CHANGED_COMPONENTS[@]}"; do
  bump="${BUMPS[$component]}"

  echo "[INFO] Bumping $component -> $bump"

  cmd=(
    "$BUMP_COMPONENT_SCRIPT"
    --component-path "$component"
    --bump-type "$bump"
  )

  if [[ "$DRY_RUN" == "true" ]]; then
    cmd+=(--dry-run)
  fi

  "${cmd[@]}"
done

echo "[INFO] Release complete."
