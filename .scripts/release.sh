#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

declare -a IGNORE_KEYS=(
  # "github/demo-hello"
)

MANIFEST="manifests/versions.yml"
DO_TAG="${DO_TAG:-0}"

function usage() {
  cat <<EOF

Usage: ${0##*/} [OPTIONS]

Options:
  --tag        Create git tags for bumped versions
  -h, --help   Show this help message

EOF
}

function path_to_key() {
  local path="$1"

  case "$path" in
    .github/workflows/*.yml|.github/workflows/*.yaml)
      local rel="${path#.github/workflows/}"
      rel="${rel%.*}"
      printf 'github/%s\n' "$rel"
      ;;
    gitlab/*.yml|gitlab/*.yaml)
      local rel="${path#gitlab/}"
      rel="${rel%.*}"
      printf 'gitlab/%s\n' "$rel"
      ;;
    concourse/*.yml|concourse/*.yaml)
      local rel="${path#concourse/}"
      rel="${rel%.*}"
      printf 'concourse/%s\n' "$rel"
      ;;
    woodpecker/*.yml|woodpecker/*.yaml)
      local rel="${path#woodpecker/}"
      rel="${rel%.*}"
      printf 'woodpecker/%s\n' "$rel"
      ;;
    *)
      return 1
      ;;
  esac
}

function bump_patch() {
  local v="$1"

  if [[ "$v" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    printf 'v%s.%s.%s\n' \
      "${BASH_REMATCH[1]}" \
      "${BASH_REMATCH[2]}" \
      "$((BASH_REMATCH[3] + 1))"
  else
    return 1
  fi
}

function set_manifest_value() {
  local file="$1"
  local key="$2"
  local value="$3"

  awk -v k="$key" -v v="$value" '
    $1 == k ":" { print k ": " v; next }
    { print }
  ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      DO_TAG=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
  shift
done

[[ -f "$MANIFEST" ]] || { echo "Manifest not found: $MANIFEST" >&2; exit 1; }

changed_files_file="${CHANGED_FILES_FILE:-}"

if [[ -z "$changed_files_file" ]]; then
  echo "CHANGED_FILES_FILE is required for manifest updates." >&2
  exit 1
fi

if [[ ! -f "$changed_files_file" ]]; then
  echo "Changed files list not found: $changed_files_file" >&2
  exit 1
fi

if [[ ! -s "$changed_files_file" ]]; then
  echo "No changed files found."
  exit 0
fi

tmp_pairs="$(mktemp)"
trap 'rm -f "$tmp_pairs" "${MANIFEST}.work"' EXIT

cp "$MANIFEST" "${MANIFEST}.work"

declare -A SEEN_KEYS=()

while IFS= read -r path; do
  [[ -z "$path" ]] && continue

  key="$(path_to_key "$path")" || continue

  for item in "${IGNORE_KEYS[@]}"; do
    [[ "$key" == "$item" ]] && continue 2
  done

  [[ -n "${SEEN_KEYS[$key]:-}" ]] && continue
  SEEN_KEYS["$key"]=1

  current="$(awk -v k="$key" '$1 == k ":" {print $2; exit}' "${MANIFEST}.work" || true)"
  [[ -z "$current" ]] && continue

  if [[ "$current" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    next="v${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.$((BASH_REMATCH[3] + 1))"
  else
    continue
  fi

  set_manifest_value "${MANIFEST}.work" "$key" "$next"
  printf '%s\t%s\t%s\n' "$key" "$current" "$next" >> "$tmp_pairs"
done < "$changed_files_file"

if [[ ! -s "$tmp_pairs" ]]; then
  echo "No releasable changes found."
  exit 0
fi

mv "${MANIFEST}.work" "$MANIFEST"

cat "$tmp_pairs"
