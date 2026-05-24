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
  --dry-run
  --no-push
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

cd "$REPO_ROOT"

mapfile -t COMPONENTS < <(
  find . -type f -name ".bumpversion.toml" -exec dirname {} + | sort -u
)

CHANGED=()

for c in "${COMPONENTS[@]}"; do
  c="${c#./}"
  if ! git diff --quiet "${BASE_REF}...HEAD" -- "$c"; then
    CHANGED+=("$c")
  fi
done

[[ ${#CHANGED[@]} -eq 0 ]] && {
  echo "[INFO] No changed components."
  exit 0
}

echo "[INFO] Changed components:"
printf ' - %s\n' "${CHANGED[@]}"

for component in "${CHANGED[@]}"; do
  commits="$(git log --format=%s "${BASE_REF}...HEAD" -- "$component" || true)"

  if echo "$commits" | grep -q 'BREAKING CHANGE\|!:'; then
    bump="major"
  elif echo "$commits" | grep -q '^feat'; then
    bump="minor"
  else
    bump="patch"
  fi

  echo "[INFO] Bumping $component -> $bump"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] bump-component.sh $component $bump"
  else
    "$SCRIPT_DIR/bump-component.sh" \
      --component-path "$component" \
      --bump-type "$bump"
  fi
done

if [[ "$COMMIT" == "true" && "$DRY_RUN" != "true" ]]; then
  git add .
  git commit -m "chore(release): bump component versions" || true
fi

echo "[INFO] Done. Run git-tag-components.sh to sync tags."
