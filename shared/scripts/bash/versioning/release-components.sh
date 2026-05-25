#!/usr/bin/env bash
set -euo pipefail

######################################################################
# Component release orchestrator script.                             #
#                                                                    #
# Detects changed components, bumps versions, and optionally commits #
# the result.                                                        #
#                                                                    #
# A component is any directory containing a .bumpversion.toml file.  #
#                                                                    #
# Version bump rules:                                                #
#   Breaking change / feat! -> major                                 #
#   feat                    -> minor                                 #
#   everything else         -> patch                                 #
######################################################################

BASE_REF="${BASE_REF:-}"
DRY_RUN="false"
COMMIT="${COMMIT:-true}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(realpath -m "$SCRIPT_DIR/../../../..")"

function usage() {
  cat <<EOF
Usage: ${0} [OPTIONS]

Options:
  --dry-run
  --no-commit
  -h, --help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run)
    DRY_RUN="true"
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

cd "$REPO_ROOT"

git fetch origin main >/dev/null 2>&1 || true

if [[ -z "$BASE_REF" ]]; then
  BASE_REF="$(git merge-base HEAD origin/main)"
fi

mapfile -t COMPONENTS < <(
  find . -type f -name ".bumpversion.toml" -exec dirname {} + | sort -u
)

CHANGED_COMPONENTS=()

for c in "${COMPONENTS[@]}"; do
  c="${c#./}"

  version_file="$c/VERSION"
  if [[ -f "$version_file" ]]; then
    v="$(tr -d '[:space:]' <"$version_file")"
    if [[ "$v" == "0.0.0" ]]; then
      CHANGED_COMPONENTS+=("$c")
      continue
    fi
  fi

  if git log --oneline "${BASE_REF}..HEAD" -- "$c" | grep -q .; then
    CHANGED_COMPONENTS+=("$c")
  fi
done

if [[ ${#CHANGED_COMPONENTS[@]} -eq 0 ]]; then
  echo "[INFO] No changed components."
  exit 0
fi

echo "[INFO] Changed components:"
printf ' - %s\n' "${CHANGED_COMPONENTS[@]}"

VERSION_FILES=()

for component in "${CHANGED_COMPONENTS[@]}"; do
  commits="$(git log --format=%s "${BASE_REF}..HEAD" -- "$component" || true)"

  if echo "$commits" | grep -q 'BREAKING CHANGE\|!:'; then
    bump="major"
  elif echo "$commits" | grep -q '^feat'; then
    bump="minor"
  else
    bump="patch"
  fi

  echo "[INFO] Bumping $component -> $bump"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] $SCRIPT_DIR/bump-component.sh --component-path $component --bump-type $bump"
  else
    "$SCRIPT_DIR/bump-component.sh" \
      --component-path "$component" \
      --bump-type "$bump"
  fi

  VERSION_FILES+=("$component/VERSION")
done

if [[ "$COMMIT" == "true" && "$DRY_RUN" != "true" ]]; then
  if ! git diff --quiet; then
    git add "${VERSION_FILES[@]}"
    git commit -m "chore(release): bump component versions"
  else
    echo "[INFO] No version changes to commit."
  fi
fi

echo "[INFO] Release complete."
