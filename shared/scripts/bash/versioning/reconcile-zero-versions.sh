#!/usr/bin/env bash
set -euo pipefail

#################################################################
# Ensures all components are at least version 0.0.1.            #
#                                                               #
# Finds all components with a version of 0.0.0, then bumps them #
# to 0.0.1.                                                     #
#################################################################

BASE_DIR="${BASE_DIR:-.}"
BRANCH_NAME="${BRANCH_NAME:-chore/reconcile-zero-versions}"
COMMIT_MESSAGE="${COMMIT_MESSAGE:-chore(versioning): reconcile zero versions}"
DRY_RUN="false"

function usage() {
  cat <<EOF
Usage: ${0} [OPTIONS]

Options:
  --dry-run     Show what would change without modifying files
  -h, --help    Print help menu
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run)
    DRY_RUN="true"
    shift
    ;;
  -h | --help)
    usage
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
  echo "[INFO] No 0.0.0 versions found."
  exit 0
fi

echo "[INFO] Zero-version components:"
printf ' - %s\n' "${ZERO_VERSION_FILES[@]}"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY RUN] Would bump these versions to 0.0.1 and open a PR."
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

for vf in "${ZERO_VERSION_FILES[@]}"; do
  printf '0.0.1\n' >"$vf"
done

git checkout -b "$BRANCH_NAME"
git add "${ZERO_VERSION_FILES[@]}"
git commit -m "$COMMIT_MESSAGE"

echo "[INFO] Created branch $BRANCH_NAME with zero-version fixes."
