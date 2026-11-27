#!/usr/bin/env bash
set -euo pipefail

########################################################################
# Release changed components automatically using conventional commits. #
#                                                                      #
# A component is any directory containing a .bumpversion.toml file.    #
#                                                                      #
# Version bump rules:                                                  #
#   Breaking change / feat! -> major                                   #
#   feat                    -> minor                                   #
#   everything else         -> patch                                   #
#                                                                      #
# Components at 0.0.0 are always bumped (to 0.0.1).                    #
# Release bump commits are ignored to avoid bump loops.                #
########################################################################

_BUMP_COMPONENTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(realpath -m "${_BUMP_COMPONENTS_DIR}/../../../..")"
BUMP_COMPONENT_SCRIPT="${_BUMP_COMPONENTS_DIR}/bump-component.sh"
RELEASE_COMMIT_PATTERN='^chore\(release\): bump component versions'

BASE_REF="${BASE_REF:-}"
DRY_RUN="false"
CWD=$(pwd)

function usage() {
  cat <<EOF
Usage: ${0} [OPTIONS]

Options:
  -h, --help   Print this help menu
  --dry-run    Describe operations without actually taking them
EOF
}

function cleanup() {
  cd "${CWD}"
}
trap cleanup EXIT

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

cd "${REPO_ROOT}"

if [[ -z "$BASE_REF" ]]; then
  git fetch origin main --quiet || true
  BASE_REF="$(git merge-base HEAD origin/main)"
fi

## Commit subjects touching a component, excluding release bump commits
function component_commits() {
  local component="$1"

  git log --format=%s "${BASE_REF}..HEAD" -- "${component}" |
    grep -Ev "${RELEASE_COMMIT_PATTERN}" || true
}

## Determine highest bump level from commit history
function determine_bump_type() {
  local component="$1"
  local commits

  commits="$(component_commits "${component}")"

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

## Discover all bumpable components
mapfile -t COMPONENTS < <(
  find . -type f -name ".bumpversion.toml" -not -path './.git/*' -exec dirname {} + | sort -u
)

if [[ ${#COMPONENTS[@]} -eq 0 ]]; then
  echo "[INFO] No bumpable components found."
  exit 0
fi

released_any="false"

for component in "${COMPONENTS[@]}"; do
  component="${component#./}"
  version_file="${component}/VERSION"
  bump_type=""

  ## Skip if VERSION already changed in this range (already bumped)
  if git diff --name-only "${BASE_REF}..HEAD" -- "${version_file}" | grep -q .; then
    echo "[INFO] ${component} VERSION already changed in this range; skipping."
    continue
  fi

  if [[ -f "${version_file}" ]] && [[ "$(tr -d '[:space:]' <"${version_file}")" == "0.0.0" ]]; then
    bump_type="patch"
  else
    bump_type="$(determine_bump_type "${component}")"
  fi

  if [[ -z "${bump_type}" ]]; then
    continue
  fi

  echo "[INFO] Releasing ${component} (${bump_type})"

  cmd=(
    "${BUMP_COMPONENT_SCRIPT}"
    --component-path "${component}"
    --bump-type "${bump_type}"
  )

  if [[ "${DRY_RUN}" == "true" ]]; then
    cmd+=(--dry-run)
  fi

  "${cmd[@]}"

  released_any="true"
done

if [[ "${released_any}" != "true" ]]; then
  echo "[INFO] No changed components detected."
fi
