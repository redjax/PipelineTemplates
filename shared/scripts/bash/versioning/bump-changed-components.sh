#!/usr/bin/env bash
set -euo pipefail

########################################################################
# Release changed components automatically using conventional commits. #
#                                                                      #
# A component is any directory containing a .bumpversion.toml file     #
#                                                                      #
# Version bump rules:                                                  #
#   Breaking change / feat! -> major                                   #
#   feat                    -> minor                                   #
#   everything else         -> patch                                   #
########################################################################

_BUMP_COMPONENTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(realpath -m "${_BUMP_COMPONENTS_DIR}/../../../..")"

BASE_REF="${BASE_REF:-}"
DRY_RUN="false"
CWD=$(pwd)

if [[ -z "$BASE_REF" ]]; then
  git fetch origin main --quiet || true
  BASE_REF="$(git merge-base HEAD origin/main)"
fi

function usage() {
  cat <<EOF
Usage: ${0} [OPTIONS]

Options:
  -h, --help   Print this help menu
  --dry-run    Describe operations without actually taking them
EOF
}

## Parse CLI args
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
    echo "[ERROR] Invalid arg: $1" >&2
    exit 1
    ;;
  esac
done

function cleanup() {
  cd "${CWD}"
}
trap cleanup EXIT

## Determine highest bump level from commit history
function determine_bump_type() {
  local component="$1"

  local commits
  commits="$(
    git log \
      --format=%s \
      "${BASE_REF}..HEAD" \
      -- "${component}"
  )"

  if [[ -z "${commits}" ]]; then
    echo ""
    return
  fi

  if echo "${commits}" | grep -Eq 'BREAKING CHANGE|!:'; then
    echo "major"
    return
  fi

  if echo "${commits}" | grep -Eq '^feat(\(.+\))?:'; then
    echo "minor"
    return
  fi

  echo "patch"
}

cd "${REPO_ROOT}"

## Discover all bumpable components
mapfile -t COMPONENTS < <(
  while IFS= read -r file; do
    dirname "$file"
  done < <(
    find . -type f -name ".bumpversion.toml"
  ) | sort -u
)

if [[ ${#COMPONENTS[@]} -eq 0 ]]; then
  echo "[INFO] No bumpable components found."
  exit 0
fi

released_any="false"

for component in "${COMPONENTS[@]}"; do

  ## Skip unchanged components
  if ! git diff --quiet "${BASE_REF}...HEAD" -- "${component}"; then

    bump_type="$(determine_bump_type "${component}")"

    if [[ -z "${bump_type}" ]]; then
      echo "[INFO] No commits found for ${component}"
      continue
    fi

    echo "[INFO] Releasing ${component} (${bump_type})"

    cmd=(
      "${REPO_ROOT}/.scripts/versioning/bump-component.sh"
      --component-path "${component}"
      --bump-type "${bump_type}"
    )

    if [[ "${DRY_RUN}" == "true" ]]; then
      cmd+=(--dry-run)
    fi

    "${cmd[@]}"

    released_any="true"
  fi
done

if [[ "${released_any}" != "true" ]]; then
  echo "[INFO] No changed components detected."
fi
