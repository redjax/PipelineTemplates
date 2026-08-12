#!/usr/bin/env bash
set -euo pipefail

module_dir="${MODULE_DIR:-.}"
test_package="${TEST_PACKAGE:-./...}"
test_flags="${TEST_FLAGS:-}"
cgo_enabled="${CGO_ENABLED:-0}"

root="$PWD/app/$module_dir"

(
  cd "$root"
  CGO_ENABLED="$cgo_enabled" go test $test_flags "$test_package"
)
