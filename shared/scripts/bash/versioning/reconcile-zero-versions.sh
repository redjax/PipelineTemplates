#!/usr/bin/env bash
set -euo pipefail

#################################################################
# Ensures all components are at least version 0.0.1.            #
#                                                               #
# Finds all components with a version of 0.0.0, then bumps them #
# to 0.0.1.                                                     #
#################################################################

BASE_DIR="${BASE_DIR:-.}"
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run)
    DRY_RUN="true"
    shift
    ;;
  -h | --help)
    echo "Usage: $0 [--dry-run]" >&2
    exit 0
    ;;
  *)
    echo "[ERROR] Unknown arg: $1" >&2
    exit 1
    ;;
  esac
done

cd "$BASE_DIR"

mapfile -t VERSION_FILES < <(find . -type f -name "VERSION" | sort)

ZERO_VERSION_FILES=()
for vf in "${VERSION_FILES[@]}"; do
  version="$(tr -d '[:space:]' <"$vf")"
  if [[ "$version" == "0.0.0" ]]; then
    ZERO_VERSION_FILES+=("$vf")
  fi
done

if [[ ${#ZERO_VERSION_FILES[@]} -eq 0 ]]; then
  echo "[INFO] No 0.0.0 versions found." >&2
  echo "status=none"
  exit 0
fi

echo "[INFO] Zero-version components:" >&2
printf ' - %s\n' "${ZERO_VERSION_FILES[@]}" >&2

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY RUN] Would bump these versions to 0.0.1." >&2
  echo "status=found"
  exit 0
fi

for vf in "${ZERO_VERSION_FILES[@]}"; do
  printf '0.0.1\n' >"$vf"
done

echo "status=bumped"
