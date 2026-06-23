#!/usr/bin/env bash
set -euo pipefail

dist_dir="${DIST_DIR:-$PWD/dist}"

[[ -d "$dist_dir" ]] || {
  echo "Artifacts dir not found: $dist_dir" >&2
  exit 1
}

echo "Publish step is currently a placeholder."
echo "Found artifacts:"
find "$dist_dir" -maxdepth 1 -type f -print | sort
