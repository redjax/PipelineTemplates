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
#   HUGO_DEBUG_BUILD  (optional, "true" enables)   #
####################################################

SOURCE_DIR="${HUGO_SOURCE_DIR:-.}"
PUBLIC_DIR="${HUGO_PUBLIC_DIR:-public}"
BUILD_FLAGS="${HUGO_BUILD_FLAGS:---gc --minify}"
BASE_URL="${HUGO_BASEURL:-}"
ENVIRONMENT="${HUGO_ENVIRONMENT:-production}"
TRACE_FILE="${HUGO_TRACE_FILE:-}"
DEBUG_BUILD="${HUGO_DEBUG_BUILD:-false}"

cd "$SOURCE_DIR"

if [[ -n "$TRACE_FILE" && "$TRACE_FILE" != /* ]]; then
  TRACE_FILE="$(pwd)/$TRACE_FILE"
fi

mkdir -p "$PUBLIC_DIR"

export HUGO_ENVIRONMENT="$ENVIRONMENT"
export HUGO_ENV="$ENVIRONMENT"

args=(
  --destination "$PUBLIC_DIR"
  --environment "$ENVIRONMENT"
)

if [[ -n "$BASE_URL" ]]; then
  args+=(--baseURL "$BASE_URL")
fi

if [[ -n "$TRACE_FILE" ]]; then
  args+=(
    --trace "$TRACE_FILE"
    --templateMetrics
    --templateMetricsHints
    --logLevel debug
  )
fi

read -r -a flag_array <<<"$BUILD_FLAGS"

echo "[INFO] Working directory: $(pwd)"
echo "[INFO] Output directory: $PUBLIC_DIR"
echo "[INFO] Environment: $ENVIRONMENT"
echo "[INFO] Build flags: $BUILD_FLAGS"

echo
echo "===== Hugo command ====="
printf 'hugo '
printf '%q ' "${flag_array[@]}"
printf '%q ' "${args[@]}"
echo
echo "========================"
echo

run_hugo() {
  if [[ -n "$TRACE_FILE" ]]; then
    echo "[INFO] Hugo trace file: $TRACE_FILE"
  fi

  hugo "${flag_array[@]}" "${args[@]}"
}

if [[ "$DEBUG_BUILD" != "true" ]]; then
  run_hugo

  echo "[INFO] Hugo build completed."
  exit 0
fi

####################
# Debug build mode #
####################

set +e

run_hugo
status=$?

set -e

echo
echo "===== Hugo exit code ====="
echo "$status"

echo
echo "===== Generated pages ====="
if [[ -d "$PUBLIC_DIR" ]]; then
  find "$PUBLIC_DIR" -name index.html | sort || true
else
  echo "No public directory generated."
fi

if [[ -f "$PUBLIC_DIR/posts/first/index.html" ]]; then
  echo
  echo "===== posts/first/index.html ====="
  sed -n '1,200p' "$PUBLIC_DIR/posts/first/index.html"
fi

echo
echo "===== Hugo transform error files ====="

shopt -s nullglob
error_files=(/tmp/hugo-transform-error*)

if ((${#error_files[@]} == 0)); then
  echo "No /tmp/hugo-transform-error* files found."
else
  for f in "${error_files[@]}"; do
    echo
    echo "=================================================="
    echo "$f"
    echo "=================================================="
    sed -n '1,200p' "$f"
  done
fi

exit "$status"
