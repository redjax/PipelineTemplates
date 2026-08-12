#!/usr/bin/env bash
set -euo pipefail

# module_dir="${MODULE_DIR:-.}"
binary_name="${BINARY_NAME:?BINARY_NAME is required}"
output_dir="${OUTPUT_DIR:-dist}"

artifact_root="$PWD/output/$output_dir"

find "$artifact_root" -maxdepth 1 -type f -name "${binary_name}-*" -print
