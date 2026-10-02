#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT=$(realpath -m "${THIS_DIR}/..")
DOCS_DIR="${PROJECT_ROOT}/docs"
DOCS_SITE_PROJ_DIR="${PROJECT_ROOT}/docs-site"
BUILD_OUTPUT_DIR="${DOCS_SITE_PROJ_DIR}/site"

CWD=$(pwd)
CLEAN_BUILD="false"

cleanup() {
  cd "${CWD}"
}
trap cleanup EXIT

usage() {
  cat <<EOF
Usage:
  ${0##*/} [OPTIONS]

Options:
  -h, --help    Print this help menu.
  -c, --clean   Do a "clean" build, removing the existing site before running a build.
  -o, --output  Path to a directory where site static files will be generated.
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
  -c | --clean)
    CLEAN_BUILD="true"
    shift
    ;;
  -o | --output)
    BUILD_OUTPUT_DIR="$2"
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "[ERROR] Invalid option: $1" >&2
    echo

    usage
    exit 1
    ;;
  esac
done

if [[ ! -d "${DOCS_DIR}" ]]; then
  echo "[ERROR] Could not find docs source at path: ${DOCS_DIR}" >&2
  exit 1
fi

if [[ ! -d "${DOCS_SITE_PROJ_DIR}" ]]; then
  echo "[ERROR] Could not find Zensical site source at path: ${DOCS_SITE_PROJ_DIR}" >&2
  exit 1
fi

cd "${PROJECT_ROOT}"

build_cmd=(uv run --project "${DOCS_SITE_PROJ_DIR}" zensical build)

if [[ "${CLEAN_BUILD}" == "true" ]]; then
  if [[ -d "${BUILD_OUTPUT_DIR}" ]]; then
    echo "Doing a clean rebuild. Removing existing dir: ${BUILD_OUTPUT_DIR}"

    if ! rm -rf "${BUILD_OUTPUT_DIR}" 2>&1; then
      echo "[ERROR] Failed removing existing path." >&2
      exit 1
    fi
  fi
fi

echo
echo "Building Zensical site."
echo "[DEBUG] Command: ${build_cmd[*]}"
echo

if ! "${build_cmd[@]}" 2>&1; then
  echo "[ERROR] Failed building Zensical site." >&2
  exit 1
else
  echo
  echo "Success: Built Zensical docs site a: ${DOCS_SITE_PROJ_DIR}"
  exit 0
fi
