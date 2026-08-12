#!/usr/bin/env bash
set -euo pipefail

module_dir="${MODULE_DIR:-.}"
build_package="${BUILD_PACKAGE:?BUILD_PACKAGE is required}"
binary_name="${BINARY_NAME:?BINARY_NAME is required}"
platforms="${PLATFORMS:-linux/amd64}"
build_tags="${BUILD_TAGS:-}"
ldflags="${LDFLAGS:-}"
output_dir="${OUTPUT_DIR:-dist}"
cgo_enabled="${CGO_ENABLED:-0}"

root="$PWD/app/$module_dir"
artifact_root="$PWD/output/$output_dir"

[[ -d "$root" ]] || {
  echo "Module dir not found: $root" >&2
  exit 1
}

mkdir -p "$artifact_root"

read -r -a platform_list <<<"${platforms//,/ }"

for platform in "${platform_list[@]}"; do
  IFS=/ read -r goos goarch <<<"$platform"
  ext=""
  [[ "$goos" == "windows" ]] && ext=".exe"

  out_path="$artifact_root/${binary_name}-${goos}-${goarch}${ext}"

  args=(build -o "$out_path")
  [[ -n "$build_tags" ]] && args+=(-tags "$build_tags")
  [[ -n "$ldflags" ]] && args+=(-ldflags "$ldflags")
  args+=("$build_package")

  (
    cd "$root"
    GOOS="$goos" GOARCH="$goarch" CGO_ENABLED="$cgo_enabled" go "${args[@]}"
  )
done
