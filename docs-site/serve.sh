#!/usr/bin/env bash
set -euo pipefail

THIS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT=$(realpath -m "${THIS_DIR}/..")
DOCS_DIR="${PROJECT_ROOT}/docs"
DOCS_SITE_PROJ_DIR="${PROJECT_ROOT}/docs-site"

CWD=$(pwd)
HOST_ADDR=127.0.0.1
HOST_PORT=8118
HOST_URL="http://${HOST_ADDR}:${HOST_PORT}"

cleanup() {
  cd "${CWD}"
}
trap cleanup EXIT

usage() {
  cat <<EOF
Usage:
  ${0##*/} [OPTIONS]

Options:
  -h, --help            Print this help menu
  -b, --bind  <string>  Host Address to bind to, i.e. 127.0.0.1 (default), 0.0.0.0, 192.168.1.xxx
  -p, --port  <int>     Port to serve site on. Default: 8118
EOF
}

## Validate an IPv4 address.
is_valid_ip() {
  local ip="$1"
  local octet

  # Must contain exactly 4 numeric octets.
  [[ "$ip" =~ ^[0-9]+(\.[0-9]+){3}$ ]] || return 1

  IFS='.' read -r -a octets <<<"$ip"

  for octet in "${octets[@]}"; do
    # Reject leading zeros / non-decimal representations if desired.
    [[ "$octet" =~ ^[0-9]+$ ]] || return 1
    ((10#$octet <= 255)) || return 1
  done

  return 0
}

## Validate an HTTP/HTTPS URL.
is_valid_url() {
  local url="$1"

  [[ "$url" =~ ^https?://([^[:space:]/]+)(:[0-9]+)?(/[^[:space:]]*)?$ ]]
}

## Validate that a value is either "http" or "https".
is_http_or_https() {
  case "$1" in
  http | https)
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

## Validate whether a given string is a valid url or ip address
is_ip_or_url() {
  is_valid_ip "$1" || is_valid_url "$1"
}

## Validate TCP/UDP port
is_valid_port() {
  local port="$1"

  ## Must be a non-empty decimal integer.
  [[ "$port" =~ ^[0-9]+$ ]] || return 1

  ## Valid TCP/UDP port range: 1-65535.
  ((port >= 1 && port <= 65535))
}

while [[ $# -gt 0 ]]; do
  case $1 in
  -b | --bind)
    HOST_ADDR="$2"
    shift 2
    ;;
  -p | --port)
    HOST_PORT="$2"
    shift 2
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

echo "[DEBUG] DOCS_DIR=${DOCS_DIR}"
if [[ ! -d "${DOCS_DIR}" ]]; then
  echo "[ERROR] Could not find docs directory at path: ${DOCS_DIR}" >&2
  exit 1
fi

echo "[DEBUG] DOCS_SITE_PROJ_DIR=${DOCS_SITE_PROJ_DIR}"
if [[ ! -d "${DOCS_SITE_PROJ_DIR}" ]]; then
  echo "[ERROR] Could not find Zensical site directory at path: ${DOCS_SITE_PROJ_DIR}" >&2
  exit 1
fi

echo "[DEBUG] HOST_ADDR=${HOST_ADDR}"
if ! is_valid_ip "${HOST_ADDR}"; then
  echo "[ERROR] Invalid host address: ${HOST_ADDR}" >&2
  echo "Must use a value like 'hostname.domain', '0.0.0.0', '127.0.0.1', or '192.168.1.151'" >&2

  exit 1
fi

echo "[DEBUG] HOST_PORT=${HOST_PORT}"
if ! is_valid_port "${HOST_PORT}"; then
  echo "[ERROR] Invalid port: ${HOST_PORT}" >&2
  echo "Must use a valid TCP or UDP port in range 1-65534" >&2

  exit 1
fi

HOST_URL="${HOST_ADDR}:${HOST_PORT}"

echo "[DEBUG] Host URL: ${HOST_URL}"
if ! is_valid_url "http://${HOST_URL}"; then
  echo "[ERROR] Invalid host address: ${HOST_URL}" >&2
  echo

  usage
  exit 1
fi

cd "${PROJECT_ROOT}"

serve_cmd=(uv run --project "${DOCS_SITE_PROJ_DIR}" zensical serve --dev-addr "${HOST_URL}")

echo "[DEBUG] Zensical serve command: ${serve_cmd[*]}"
echo

echo "Serving Zensical site"
echo "  URL: ${HOST_URL}"
echo

if ! "${serve_cmd[@]}" 2>&1; then
  echo
  echo "[ERROR] Failed serving Zensical site." >&2

  exit 1
fi
