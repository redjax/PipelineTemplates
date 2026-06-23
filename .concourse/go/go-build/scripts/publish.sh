#!/usr/bin/env bash
set -euo pipefail

module_dir="${MODULE_DIR:-.}"
binary_name="${BINARY_NAME:-}"
output_dir="${OUTPUT_DIR:-dist}"

echo "!! Publish step is currently a placeholder !!"
echo
echo "module_dir=$module_dir"
echo "binary_name=${binary_name:-<unset>}"
echo "output_dir=$output_dir"
echo "Artifacts would be published here once a real artifact source is added."
