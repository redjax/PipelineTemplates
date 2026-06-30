#!/usr/bin/env bash
set -euo pipefail

cd "${HUGO_SOURCE_DIR:-.}"

PUBLIC_DIR="${HUGO_PUBLIC_DIR:-public}"
ARCHIVE_NAME="${ARCHIVE_NAME:-site}"
ARCHIVE_FORMAT="${ARCHIVE_FORMAT:-none}"
ARCHIVE_OUTPUT_DIR="${ARCHIVE_OUTPUT_DIR:-dist}"

mkdir -p "$ARCHIVE_OUTPUT_DIR"

case "$ARCHIVE_FORMAT" in
zip)
  (cd "$PUBLIC_DIR" && zip -r "../${ARCHIVE_OUTPUT_DIR}/${ARCHIVE_NAME}.zip" .)
  ;;
tar.gz)
  tar -czf "${ARCHIVE_OUTPUT_DIR}/${ARCHIVE_NAME}.tar.gz" -C "$PUBLIC_DIR" .
  ;;
both)
  (cd "$PUBLIC_DIR" && zip -r "../${ARCHIVE_OUTPUT_DIR}/${ARCHIVE_NAME}.zip" .)
  tar -czf "${ARCHIVE_OUTPUT_DIR}/${ARCHIVE_NAME}.tar.gz" -C "$PUBLIC_DIR" .
  ;;
none)
  exit 0
  ;;
*)
  echo "Unknown archive format: $ARCHIVE_FORMAT" >&2
  exit 1
  ;;
esac
