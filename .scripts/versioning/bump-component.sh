#!/usr/bin/env bash
set -euo pipefail

########################################################################
# Component version bump script                                        #
#                                                                      #
# Composes bump-my-version command and bumps a .bumpversion.toml file. #
########################################################################

if ! command -v bump-my-version >&/dev/null; then
  echo "[ERROR] bump-my-version is not installed." <&2
  exit 1
fi

_BUMP_COMPONENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT=$(realpath -m "${_BUMP_COMPONENT_DIR}/../..")

## Defaults
COMPONENT_PATH=""
BUMPVERSION_FILE=".bumpversion.toml"
BUMP_TYPE="patch"

DRY_RUN="false"
CWD=$(pwd)

function cleanup() {
  cd "${CWD}"
}
trap cleanup EXIT

## Help menu
function usage() {
  cat <<EOF
Usage: ${0} [OPTIONS]

Options:
  -h, --help    Print this help menu
EOF
}

## Function to run bump-my-version
function bump_version() {
  local bump_type="${1:-patch}"
  local bumpversion_file="${2:-}"
  local version_file
  local component_name
  local current_version
  local new_version

  version_file="$(dirname "$bumpversion_file")/VERSION"
  component_name="$(dirname "$bumpversion_file")"

  current_version="$(cat "$version_file")"

  if [[ "$DRY_RUN" == "true" ]]; then
    new_version="$(
      bump-my-version show new_version \
        --increment "$bump_type" \
        --config-file "$bumpversion_file"
    )"
  else
    bump-my-version bump "$bump_type" \
      --config-file "$bumpversion_file" \
      >/dev/null

    new_version="$(cat "$version_file")"
  fi

  msg="Bump ${component_name}: ${current_version} -> ${new_version}"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] $msg"
  else
    echo "$msg"
  fi
}

## Parse CLI args
while [[ $# -gt 0 ]]; do
  case $1 in
  -p | --component-path)
    COMPONENT_PATH="$2"
    shift 2
    ;;
  --dry-run)
    DRY_RUN="true"
    shift
    ;;
  -b | --bump-type)
    BUMP_TYPE="$2"
    shift 2
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

## Validate inputs
if [[ -n "${COMPONENT_PATH}" ]]; then
  if [[ ! -d "${COMPONENT_PATH}" ]]; then
    echo "[ERROR] Invalid component path: ${COMPONENT_PATH}. Must be a path to a valid CI component directory." >&2
    exit 1
  fi
else
  echo "[ERROR] Missing a --component-path" >&2
  exit 1
fi

if [[ "$BUMP_TYPE" != "patch" ]] && [[ "$BUMP_TYPE" != "minor" ]] && [[ "$BUMP_TYPE" != "major" ]]; then
  echo "[ERROR] Invalid bump type: $BUMP_TYPE. Must be 'patch', 'minor', or 'major'." >&2
  exit 1
fi

## Compose file paths
COMPONENT_BUMPVERSION_FILE="${COMPONENT_PATH}/${BUMPVERSION_FILE}"

cd "${REPO_ROOT}"

bump_version "${BUMP_TYPE}" "${COMPONENT_BUMPVERSION_FILE}"
