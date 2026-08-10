#!/usr/bin/env bash
set -euo pipefail

######################################################################
# Component release orchestrator script.                             #
#                                                                    #
# Detects changed components and performs version bumps.             #
#                                                                    #
# A component is any directory containing a .bumpversion.toml file.  #
#                                                                    #
# Version bump rules:                                                #
#   Breaking change / feat! -> major                                 #
#   feat                    -> minor                                 #
#   everything else         -> patch                                 #
######################################################################

BASE_REF="${BASE_REF:-}"
DRY_RUN="${DRY_RUN:-false}"
OUTPUT_FILE="${OUTPUT_FILE:-}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(realpath -m "$SCRIPT_DIR/../../../..")"

function usage() {
  cat <<EOF
Usage: ${0} [OPTIONS]

Options:
  --dry-run
  --output-file <path>
  -h, --help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run)
    DRY_RUN="true"
    shift
    ;;
  --output-file)
    OUTPUT_FILE="$2"
    shift 2
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

cd "$REPO_ROOT"

git fetch origin main >/dev/null 2>&1 || true

if [[ -z "$BASE_REF" ]]; then
  BASE_REF="$(git merge-base HEAD origin/main)"
fi

mapfile -t COMPONENTS < <(
  find . -type f -name ".bumpversion.toml" -exec dirname {} + | sort -u
)

CHANGED_COMPONENTS=()

for c in "${COMPONENTS[@]}"; do
  c="${c#./}"
  version_file="$c/VERSION"

  if [[ -f "$version_file" ]]; then
    current_version="$(tr -d '[:space:]' <"$version_file")"
    if [[ "$current_version" == "0.0.0" ]]; then
      CHANGED_COMPONENTS+=("$c")
      continue
    fi
  fi

  if git log --oneline "${BASE_REF}..HEAD" -- "$c" | grep -q .; then
    CHANGED_COMPONENTS+=("$c")
  fi
done

if [[ ${#CHANGED_COMPONENTS[@]} -eq 0 ]]; then
  echo "[INFO] No changed components."
  [[ -n "$OUTPUT_FILE" ]] && : >"$OUTPUT_FILE"
  exit 0
fi

echo "[INFO] Changed components:"
printf ' - %s\n' "${CHANGED_COMPONENTS[@]}"

if [[ -n "$OUTPUT_FILE" ]]; then
  printf '%s\n' "${CHANGED_COMPONENTS[@]}" >"$OUTPUT_FILE"
fi

for component in "${CHANGED_COMPONENTS[@]}"; do
  version_file="$component/VERSION"

  if [[ -f "$version_file" ]]; then
    if git cat-file -e "${BASE_REF}:${version_file}" 2>/dev/null; then
      if git diff --name-only "${BASE_REF}..HEAD" -- "$version_file" | grep -q .; then
        echo "[INFO] $component VERSION already changed in this release branch; skipping."
        continue
      fi
    fi
  fi

  commits="$(git log --format=%s "${BASE_REF}..HEAD" -- "$component" || true)"

  if echo "$commits" | grep -q 'BREAKING CHANGE\|!:'; then
    bump="major"
  elif echo "$commits" | grep -q '^feat'; then
    bump="minor"
  else
    bump="patch"
  fi

  echo "[INFO] Bumping $component -> $bump"

  if [[ "$DRY_RUN" == "true" ]]; then
    new_version="$(bump-my-version show new_version --increment "$bump" --config-file "$component/.bumpversion.toml")"
    echo "[DRY RUN] Would bump: ${component} -> ${new_version}"
    continue
  fi

  bump-my-version bump \
    "$bump" \
    --config-file "$component/.bumpversion.toml" \
    --allow-dirty \
    >/dev/null

  new_version="$(tr -d '[:space:]' <"$version_file")"
  echo "[INFO] Bumped ${component} -> ${new_version}"
done

echo "[INFO] Release complete."
