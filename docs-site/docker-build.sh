#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(realpath -m "${THIS_DIR}/..")"
DOCS_SITE_DIR="${REPO_ROOT}/docs-site"
DOCS_DIR="${REPO_ROOT}/docs"
ZENSICAL_CONFIG="${REPO_ROOT}/zensical.toml"

IMAGE_NAME="pipelinetemplates-docs"
TARGET="dev"

usage() {
  cat <<EOF
Build the PipelineTemplates documentation Docker image.

Usage:
  ${0##*/} [OPTIONS]

Options:
  -t, --target  TARGET  Build target: dev or prod. Default: dev.
  -n, --name    NAME    Docker image name. Default: ${IMAGE_NAME}.
  -h, --help            Print this help menu.

Examples:
  ${0##*/}

  ${0##/} --target dev
  ${0##/} --target prod
  ${0##*/} --target prod --name my-docs
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  -t | --target)
    if [[ $# -lt 2 ]]; then
      echo "[ERROR] Missing value for ${1}." >&2
      echo >&2
      usage
      exit 1
    fi

    TARGET="$2"
    shift 2
    ;;

  -n | --name)
    if [[ $# -lt 2 ]]; then
      echo "[ERROR] Missing value for ${1}." >&2
      echo >&2
      usage
      exit 1
    fi

    IMAGE_NAME="$2"
    shift 2
    ;;

  -h | --help)
    usage
    exit 0
    ;;

  *)
    echo "[ERROR] Invalid option: $1" >&2
    echo >&2
    usage
    exit 1
    ;;
  esac
done

case "${TARGET}" in
dev | prod) ;;
*)
  echo "[ERROR] Invalid target: ${TARGET}" >&2
  echo " Valid targets: dev, prod" >&2
  exit 1
  ;;
esac

if [[ ! -d "${DOCS_DIR}" ]]; then
  echo "[ERROR] Could not find docs directory: ${DOCS_DIR}" >&2
  exit 1
fi

if [[ ! -d "${DOCS_SITE_DIR}" ]]; then
  echo "[ERROR] Could not find docs-site directory: ${DOCS_SITE_DIR}" >&2
  exit 1
fi

if [[ ! -f "${DOCS_SITE_DIR}/Dockerfile" ]]; then
  echo "[ERROR] Could not find Dockerfile: ${DOCS_SITE_DIR}/Dockerfile" >&2
  exit 1
fi

if [[ ! -f "${ZENSICAL_CONFIG}" ]]; then
  echo "[ERROR] Could not find Zensical config: ${ZENSICAL_CONFIG}" >&2
  exit 1
fi

IMAGE_TAG="${IMAGE_NAME}:${TARGET}"

cd "${REPO_ROOT}"

build_cmd=(
  docker
  build
  --file "${DOCS_SITE_DIR}/Dockerfile"
  --target "${TARGET}"
  --tag "${IMAGE_TAG}"
  .
)

echo
echo "Building documentation Docker image."
echo " Target: ${TARGET}"
echo " Image: ${IMAGE_TAG}"
echo " Context: ${REPO_ROOT}"
echo
echo "[DEBUG] Command:"
printf ' %q' "${build_cmd[@]}"
echo
echo

"${build_cmd[@]}"

echo
echo "Successfully built: ${IMAGE_TAG}"
