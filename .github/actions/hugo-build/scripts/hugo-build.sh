#!/usr/bin/env bash
set -Eeuo pipefail

####################################################
# Builds a Hugo site                               #
#                                                  #
# Environment variables:                           #
#   HUGO_SOURCE_DIR   (default .)                  #
#   HUGO_BASEURL      (optional)                   #
#   HUGO_BUILD_FLAGS  (default "--gc --minify")    #
#   HUGO_ENVIRONMENT  (optional, e.g. production)  #
####################################################

SOURCE_DIR="${HUGO_SOURCE_DIR:-.}"
BUILD_FLAGS="${HUGO_BUILD_FLAGS:---gc --minify}"

cd "$SOURCE_DIR"

echo "[INFO] Building Hugo site in $SOURCE_DIR"
echo "[INFO] Flags: $BUILD_FLAGS"

export HUGO_BASEURL="${HUGO_BASEURL:-$HUGO_BASEURL}"
export HUGO_ENVIRONMENT="${HUGO_ENVIRONMENT:-$HUGO_ENVIRONMENT}"

hugo $BUILD_FLAGS

echo "[INFO] Hugo build completed."
