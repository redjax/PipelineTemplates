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
####################################################

SOURCE_DIR="${HUGO_SOURCE_DIR:-.}"
PUBLIC_DIR="${HUGO_PUBLIC_DIR:-public}"
BUILD_FLAGS="${HUGO_BUILD_FLAGS:---gc --minify --enableGitInfo}"
BASE_URL="${HUGO_BASEURL:-}"
ENVIRONMENT="${HUGO_ENVIRONMENT:-}"

cd "$SOURCE_DIR"

mkdir -p "$PUBLIC_DIR"

args=()
if [[ -n "$BASE_URL" ]]; then
  args+=(--baseURL "$BASE_URL")
fi

if [[ -n "$ENVIRONMENT" ]]; then
  export HUGO_ENVIRONMENT="$ENVIRONMENT"
  export HUGO_ENV="$ENVIRONMENT"
fi

read -r -a flag_array <<<"$BUILD_FLAGS"

echo "[INFO] Building Hugo site in: $SOURCE_DIR"
echo "[INFO] Output directory: $PUBLIC_DIR"
echo "[INFO] Build flags: $BUILD_FLAGS"

hugo --destination "$PUBLIC_DIR" "${flag_array[@]}" "${args[@]}"

echo "[INFO] Hugo build completed."
