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
GIT_USERNAME=${GIT_CONFIG_USER:-github-actions[bot]}
GIT_EMAIL=${GIT_CONFIG_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}
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
  echo "[INFO] No 0.0.0 versions found." >&2
  exit 0
fi

echo "[INFO] Zero-version components:" >&2
printf ' - %s\n' "${ZERO_VERSION_FILES[@]}" >&2

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY RUN] Would bump these versions to 0.0.1 and open a PR." >&2
  exit 0
fi

if [[ -z "${GIT_USERNAME}" ]]; then
  echo "[ERROR] Missing git username" >&2
  exit 1
fi

if [[ -z "${GIT_EMAIL}" ]]; then
  echo "[ERROR] Missing git email address" >&2
  exit 1
fi

git config user.name "${GIT_USERNAME}"
git config user.email "${GIT_EMAIL}"

git checkout -b "${BRANCH_NAME}" >&2

for vf in "${ZERO_VERSION_FILES[@]}"; do
  printf '0.0.1\n' >"$vf"
done

git add "${ZERO_VERSION_FILES[@]}"
git commit -m "${COMMIT_MESSAGE}" >&2

echo "${BRANCH_NAME}"
