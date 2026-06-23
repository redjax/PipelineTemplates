#!/usr/bin/env bash
set -euo pipefail

module_dir="${MODULE_DIR:-.}"
root="$PWD/app/$module_dir"

[[ -d "$root" ]] || {
  echo "Module dir not found: $root" >&2
  exit 1
}

cd "$root"
go test ./...
