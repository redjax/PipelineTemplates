#!/usr/bin/env bash
set -euo pipefail

######################################################################
# Component release orchestrator script.                             #
#                                                                    #
# Detects changed components, bumps versions, and optionally commits #
# the result.                                                        #
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
COMMIT="${COMMIT:-true}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(realpath -m "$SCRIPT_DIR/../../../..")"

function usage() {
  cat <<EOF
Usage: ${0} [OPTIONS]

Options:
  --dry-run
  --no-commit
  -h, --help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run)
    DRY_RUN="true"
    shift
    ;;
  --no-commit)
    COMMIT="false"
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

  ## If this is a new component whose VERSION is still 0.0.0, treat it as changed
  if [[ -f "$version_file" ]]; then
    current_version="$(tr -d '[:space:]' <"$version_file")"
    if [[ "$current_version" == "0.0.0" ]]; then
      CHANGED_COMPONENTS+=("$c")
      continue
    fi
  fi

  ## Only treat as changed if there are commits touching this component in this PR
  if git log --oneline "${BASE_REF}..HEAD" -- "$c" | grep -q .; then
    CHANGED_COMPONENTS+=("$c")
  fi
done

if [[ ${#CHANGED_COMPONENTS[@]} -eq 0 ]]; then
  echo "[INFO] No changed components."
  exit 0
fi

echo "[INFO] Changed components:"
printf ' - %s\n' "${CHANGED_COMPONENTS[@]}"

for component in "${CHANGED_COMPONENTS[@]}"; do
  version_file="$component/VERSION"

  if [[ -f "$version_file" ]]; then
    ## If file exists in the BASE_REF, then a diff means it was modified
    #  and we should skip rebumping. If not, it's a new file and we should bump it.
    if git cat-file -e "${BASE_REF}:${version_file}" 2>/dev/null; then
      if git diff --name-only "${BASE_REF}..HEAD" -- "$version_file" | grep -q .; then
        echo "[INFO] $component VERSION already changed in this PR; skipping additional bump."
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

  prefix="unknown"
  case "$component" in
  .github/*) prefix="gh" ;;
  .forgejo/*) prefix="fj" ;;
  gitlab/*) prefix="gl" ;;
  woodpecker/*) prefix="woodpecker" ;;
  concourse/*) prefix="concourse" ;;
  esac

  component_name="${component##*/}"

  if [[ "$DRY_RUN" == "true" ]]; then
    new_version="$(bump-my-version show new_version --increment "$bump" --config-file "$component/.bumpversion.toml")"
    echo "[INFO] Would bump $component -> $bump"
    echo "[INFO] Would create tag: ${prefix}/${component_name}/v${new_version}"
    continue
  fi

  echo "[INFO] Bumping $component -> $bump"
done

echo "[INFO] Release preview complete."
