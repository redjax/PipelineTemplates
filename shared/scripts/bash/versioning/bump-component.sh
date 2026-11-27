#!/usr/bin/env bash
set -euo pipefail

########################################################################
# Component version bump script                                        #
#                                                                      #
# Composes bump-my-version command and bumps a .bumpversion.toml file. #
########################################################################

if ! command -v bump-my-version >/dev/null 2>&1; then
  echo "[ERROR] bump-my-version is not installed." >&2
  exit 1
fi

_BUMP_COMPONENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="${REPO_ROOT:-$(realpath -m "${_BUMP_COMPONENT_DIR}/../../../..")}"

COMPONENT_PATH=""
BUMPVERSION_FILE=".bumpversion.toml"
BUMP_TYPE="patch"
DRY_RUN="false"
FIRST_RELEASE_VERSION="0.0.1"
CWD=$(pwd)

function cleanup() {
  cd "${CWD}"
}
trap cleanup EXIT

## Help menu
function usage() {
  cat <<EOF
Usage:
  $(basename "$0") --component-path <path> --bump-type <patch|minor|major> [OPTIONS]

Description:
  Updates the VERSION file for a given component using bump-my-version. Reads from the
  component's .bumpversion.toml to determine versioning logic.

  Components at 0.0.0 are bumped straight to ${FIRST_RELEASE_VERSION}, regardless of bump type.

Options:
  -h, --help             Show this help message
  -p, --component-path   Path to component directory containing .bumpversion.toml (required)
  --dry-run              Show what would change without modifying files
  -b, --bump-type        Version bump type (default: patch)
                         Allowed values:
                           - patch
                           - minor
                           - major

Examples:
  $0 --component-path .github/actions/hello --bump-type patch
  $0 -p services/api -b minor --dry-run
EOF
}

## Function to run bump-my-version
#
#  bump-my-version resolves filenames in the config relative to the config
#  file's directory, so the config must use bare names (VERSION, .bumpversion.toml).
#  It updates VERSION and current_version together, so nothing else writes VERSION.
function bump_version() {
  local bump_type="${1:-patch}"
  local bumpversion_file="${2:-}"
  local component_dir
  local version_file
  local current_version
  local new_version
  local msg

  component_dir="$(dirname "$bumpversion_file")"
  version_file="${component_dir}/VERSION"

  current_version="$(tr -d '[:space:]' <"$version_file")"

  if [[ "$current_version" == "0.0.0" ]]; then
    ## First release: jump to 0.0.1 no matter the bump type
    if [[ "$DRY_RUN" == "true" ]]; then
      new_version="$FIRST_RELEASE_VERSION"
    else
      bump-my-version bump \
        --new-version "$FIRST_RELEASE_VERSION" \
        --config-file "$bumpversion_file" \
        --allow-dirty \
        >/dev/null
      new_version="$(tr -d '[:space:]' <"$version_file")"
    fi
  elif [[ "$DRY_RUN" == "true" ]]; then
    new_version="$(
      bump-my-version show new_version \
        --increment "$bump_type" \
        --config-file "$bumpversion_file"
    )"
  else
    bump-my-version bump "$bump_type" \
      --config-file "$bumpversion_file" \
      --allow-dirty \
      >/dev/null
    new_version="$(tr -d '[:space:]' <"$version_file")"
  fi

  msg="Bump ${component_dir}: ${current_version} -> ${new_version}"
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

cd "${REPO_ROOT}"

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
COMPONENT_BUMPVERSION_FILE="${COMPONENT_PATH%/}/${BUMPVERSION_FILE}"

if [[ ! -f "${COMPONENT_BUMPVERSION_FILE}" ]] || [[ ! -f "${COMPONENT_PATH%/}/VERSION" ]]; then
  echo "[ERROR] ${COMPONENT_PATH} must contain both ${BUMPVERSION_FILE} and VERSION." >&2
  exit 1
fi

bump_version "${BUMP_TYPE}" "${COMPONENT_BUMPVERSION_FILE}"
