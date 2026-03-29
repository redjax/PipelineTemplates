#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

declare -a IGNORE_KEYS=(
  # "github/demo-hello"
)

MANIFEST="manifests/versions.yml"

function usage() {
  cat <<EOF


Usage: ${0##*/}

Environment:
  CHANGED_FILES_FILE   Required. Path to temp file of changed paths.
  BASE_MANIFEST_FILE   Required. Path to base/merge-base manifest snapshot.


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
    gitlab/*.yml|gitlab/*.yaml|gitlab/*/*.yml|gitlab/*/*.yaml|gitlab/*/*/*.yml|gitlab/*/*/*.yaml)
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

function set_manifest_value() {
  local file="$1"
  local key="$2"
  local value="$3"

  awk -v k="$key" -v v="$value" '
    $1 == k ":" { print k ": " v; next }
    { print }
  ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

function lookup_value() {
  local file="$1"
  local key="$2"
  awk -v k="$key" '$1 == k ":" { print $2; exit }' "$file"
}

[[ -f "$MANIFEST" ]] || { echo "Manifest not found: $MANIFEST" >&2; exit 1; }

changed_files_file="${CHANGED_FILES_FILE:-}"
base_manifest_file="${BASE_MANIFEST_FILE:-}"

[[ -n "$changed_files_file" ]] || { echo "CHANGED_FILES_FILE is required." >&2; exit 1; }
[[ -n "$base_manifest_file" ]] || { echo "BASE_MANIFEST_FILE is required." >&2; exit 1; }
[[ -f "$changed_files_file" ]] || { echo "Changed files list not found: $changed_files_file" >&2; exit 1; }
[[ -f "$base_manifest_file" ]] || { echo "Base manifest file not found: $base_manifest_file" >&2; exit 1; }
[[ -s "$changed_files_file" ]] || { echo "No changed files found." >&2; exit 0; }

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

  base_value="$(lookup_value "$base_manifest_file" "$key")"
  current_value="$(lookup_value "${MANIFEST}.work" "$key")"

  [[ -z "$base_value" ]] && continue
  [[ -z "$current_value" ]] && continue

  if [[ "$current_value" != "$base_value" ]]; then
    continue
  fi

  if [[ "$current_value" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    next="v${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.$((BASH_REMATCH[3] + 1))"
  else
    continue
  fi

  set_manifest_value "${MANIFEST}.work" "$key" "$next"
  printf '%s\t%s\t%s\n' "$key" "$current_value" "$next" >> "$tmp_pairs"
done < "$changed_files_file"

if [[ ! -s "$tmp_pairs" ]]; then
  echo "No releasable changes found."
  exit 0
fi

mv "${MANIFEST}.work" "$MANIFEST"
cat "$tmp_pairs"
