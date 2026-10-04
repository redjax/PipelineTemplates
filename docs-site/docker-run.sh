#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(realpath -m "${THIS_DIR}/..")"
DOCS_SITE_DIR="${REPO_ROOT}/docs-site"
DOCS_DIR="${REPO_ROOT}/docs"
ZENSICAL_CONFIG="${REPO_ROOT}/zensical.toml"

IMAGE_NAME="pipelinetemplates-docs"
TARGET="dev"

HOST_PORT=""
CONTAINER_PORT=""

DEV_HOST_PORT=8118
DEV_CONTAINER_PORT=8118

PROD_HOST_PORT=80
PROD_CONTAINER_PORT=8080

BUILD="false"

usage() {
  cat <<EOF
Run the PipelineTemplates documentation Docker image.

Usage:
  ${0##*/} [OPTIONS]

Options:
  -t, --target  TARGET  Container target: dev or prod. Default: dev.
  -p, --port    PORT    Host port to bind. Defaults to 8118 for dev, 8080 for prod.
  -b, --build           Rebuild the Docker image before running.
  -h, --help            Print this help menu.

Examples:
  ${0##*/}

  ${0##/} --target dev
  ${0##/} --target dev --port 9000
  ${0##*/} --target dev --build

  ${0##/} --target prod
  ${0##/} --target prod --port 9000
  ${0##*/} --target prod --build
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

  -p | --port)
    if [[ $# -lt 2 ]]; then
      echo "[ERROR] Missing value for ${1}." >&2
      echo >&2
      usage
      exit 1
    fi

    HOST_PORT="$2"
    shift 2
    ;;

  -b | --build)
    BUILD="true"
    shift
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
dev)
  DEFAULT_HOST_PORT="${DEV_HOST_PORT}"
  CONTAINER_PORT="${DEV_CONTAINER_PORT}"
  ;;

prod)
  DEFAULT_HOST_PORT="${PROD_HOST_PORT}"
  CONTAINER_PORT="${PROD_CONTAINER_PORT}"
  ;;

*)
  echo "[ERROR] Invalid target: ${TARGET}" >&2
  echo " Valid targets: dev, prod" >&2
  exit 1
  ;;
esac

HOST_PORT="${HOST_PORT:-${DEFAULT_HOST_PORT}}"

if ! [[ "${HOST_PORT}" =~ ^[0-9]+$ ]] ||
  ((HOST_PORT < 1 || HOST_PORT > 65535)); then
  echo "[ERROR] Invalid host port: ${HOST_PORT}" >&2
  echo " Port must be between 1 and 65535." >&2
  exit 1
fi

if [[ ! -d "${DOCS_DIR}" ]]; then
  echo "[ERROR] Could not find docs directory: ${DOCS_DIR}" >&2
  exit 1
fi

if [[ ! -d "${DOCS_SITE_DIR}" ]]; then
  echo "[ERROR] Could not find docs-site directory: ${DOCS_SITE_DIR}" >&2
  exit 1
fi

if [[ ! -f "${ZENSICAL_CONFIG}" ]]; then
  echo "[ERROR] Could not find Zensical config: ${ZENSICAL_CONFIG}" >&2
  exit 1
fi

IMAGE_TAG="${IMAGE_NAME}:${TARGET}"

cd "${REPO_ROOT}"

if [[ "${BUILD}" == "true" ]]; then
  echo
  echo "Building Docker image: ${IMAGE_TAG}"
  echo

  "${DOCS_SITE_DIR}/docker-build.sh" --target "${TARGET}"
fi

if ! docker image inspect "${IMAGE_TAG}" >/dev/null 2>&1; then
  echo "[ERROR] Docker image does not exist: ${IMAGE_TAG}" >&2
  echo >&2
  echo "Build it first with:" >&2
  echo " ${DOCS_SITE_DIR}/docker-build.sh --target ${TARGET}" >&2
  echo >&2
  echo "Or use --build:" >&2
  echo " ${0##*/} --target ${TARGET} --build" >&2
  exit 1
fi

run_cmd=(
  docker
  run
  -d
  --rm
  --init
  --name "${IMAGE_NAME}-${TARGET}"
  --publish "${HOST_PORT}:${CONTAINER_PORT}"
)

if [[ "${TARGET}" == "dev" ]]; then
  run_cmd+=(
    --volume "${DOCS_DIR}:/workspace/docs:ro"
    --volume "${DOCS_SITE_DIR}:/workspace/docs-site"
    --volume "${ZENSICAL_CONFIG}:/workspace/zensical.toml:ro"
    --volume "${IMAGE_NAME}-venv:/workspace/docs-site/.venv"
  )
fi

run_cmd+=("${IMAGE_TAG}")

echo
echo "Running documentation site."
echo " Target: ${TARGET}"
echo " Image: ${IMAGE_TAG}"
echo " URL: http://localhost:${HOST_PORT}"

if [[ "${TARGET}" == "dev" ]]; then
  echo " Mode: hot reload"
fi

echo
echo "[DEBUG] Command:"
printf ' %q' "${run_cmd[@]}"
echo
echo

"${run_cmd[@]}"
