#!/usr/bin/env bash
set -Eeuo pipefail

####################################################
# Builds a Hugo site                               #
#                                                  #
# Environment variables:                           #
#   HUGO_SOURCE_DIR   (default .)                  #
#   HUGO_PUBLIC_DIR   (default public)             #
#   HUGO_BASEURL      (optional)                   #
#   HUGO_BUILD_FLAGS  (default "--gc --minify")    #
#   HUGO_ENVIRONMENT  (optional, e.g. production)  #
#   HUGO_TRACE_FILE   (optional, e.g. trace.txt)   #
####################################################

SOURCE_DIR="${HUGO_SOURCE_DIR:-.}"
PUBLIC_DIR="${HUGO_PUBLIC_DIR:-public}"
BUILD_FLAGS="${HUGO_BUILD_FLAGS:---gc --minify}"
BASE_URL="${HUGO_BASEURL:-}"
ENVIRONMENT="${HUGO_ENVIRONMENT:-production}"
TRACE_FILE="${HUGO_TRACE_FILE:-}"

cd "$SOURCE_DIR"

mkdir -p "$PUBLIC_DIR"

export HUGO_ENVIRONMENT="$ENVIRONMENT"
export HUGO_ENV="$ENVIRONMENT"

args=(--destination "$PUBLIC_DIR" --environment "$ENVIRONMENT")

if [[ -n "$BASE_URL" ]]; then
  args+=(--baseURL "$BASE_URL")
fi

if [[ -n "$TRACE_FILE" ]]; then
  args+=(--trace "$TRACE_FILE" --templateMetrics --templateMetricsHints --logLevel debug)
fi

read -r -a flag_array <<<"$BUILD_FLAGS"

echo "[INFO] Building Hugo site in: $SOURCE_DIR"
echo "[INFO] Output directory: $PUBLIC_DIR"
echo "[INFO] Environment: $ENVIRONMENT"
echo "[INFO] Build flags: $BUILD_FLAGS"

hugo "${flag_array[@]}" "${args[@]}"

echo "[INFO] Hugo build completed."
