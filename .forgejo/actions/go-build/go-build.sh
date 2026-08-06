#!/usr/bin/env bash
set -euo pipefail

module_dir="${MODULE_DIR:-.}"
build_package="${BUILD_PACKAGE:?BUILD_PACKAGE is required}"
binary_name="${BINARY_NAME:?BINARY_NAME is required}"

platforms="${PLATFORMS:-linux/amd64}"
build_tags="${BUILD_TAGS:-}"
ldflags="${LDFLAGS:-}"
output_dir="${OUTPUT_DIR:-dist}"

module_root="${PWD}/${module_dir}"

if [[ ! -d "${module_root}" ]]; then
  echo "ERROR: module directory does not exist:"
  echo "  ${module_root}"
  exit 1
fi

if [[ ! -f "${module_root}/go.mod" ]]; then
  echo "ERROR: no go.mod found:"
  echo "  ${module_root}/go.mod"
  echo
  echo "MODULE_DIR must point to the Go module root."
  exit 1
fi

echo "========================================"
echo "Go build configuration"
echo "========================================"
echo "Module root:"
echo "  ${module_root}"
echo
echo "Package:"
echo "  ${build_package}"
echo
echo "Binary:"
echo "  ${binary_name}"
echo
echo "Platforms:"
echo "  ${platforms}"
echo
echo "Output:"
echo "  ${output_dir}"
echo "----------------------------------------"

mkdir -p "${module_root}/${output_dir}"

(
  cd "${module_root}"

  echo
  echo "Working directory:"
  pwd

  echo
  echo "Go module:"
  go env GOMOD

  echo
  echo "Go packages:"
  go list ./...

  echo
  echo "Requested build package:"
  go list "${build_package}"
)

read -ra platform_list <<<"${platforms//,/ }"

for platform in "${platform_list[@]}"; do

  IFS="/" read -r goos goarch <<<"${platform}"

  if [[ -z "${goos}" || -z "${goarch}" ]]; then
    echo "ERROR: invalid platform '${platform}'"
    echo "Expected format: GOOS/GOARCH"
    exit 1
  fi

  out_path="${module_root}/${output_dir}/${binary_name}-${goos}-${goarch}"

  args=(
    build
    -o "${out_path}"
  )

  if [[ -n "${build_tags}" ]]; then
    args+=(
      -tags
      "${build_tags}"
    )
  fi

  if [[ -n "${ldflags}" ]]; then
    args+=(
      -ldflags
      "${ldflags}"
    )
  fi

  args+=(
    "${build_package}"
  )

  echo
  echo "========================================"
  echo "Building"
  echo "========================================"
  echo "GOOS=${goos}"
  echo "GOARCH=${goarch}"
  echo "Output=${out_path}"
  echo

  (
    cd "${module_root}"

    echo "Command:"
    printf 'GOOS=%q GOARCH=%q CGO_ENABLED=%q go' \
      "${goos}" \
      "${goarch}" \
      "${CGO_ENABLED:-0}"

    printf ' %q' "${args[@]}"
    echo
    echo

    GOOS="${goos}" \
      GOARCH="${goarch}" \
      CGO_ENABLED="${CGO_ENABLED:-0}" \
      go "${args[@]}"
  )

  echo
  echo "Built:"
  echo "  ${out_path}"
  echo
  echo "----------------------------------------"

done

echo
echo "Build complete."
