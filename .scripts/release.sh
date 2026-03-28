#!/usr/bin/env bash
set -euo pipefail

MANIFEST="manifests/versions.yml"
DO_TAG="${DO_TAG:-0}"

function usage() {
  echo ""
  echo "Usage: ${0} [OPTIONS]"
  echo ""
  echo "  --tag  <bool>   Create git tags for bumped versions"
  echo ""
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

## Map pipeline filepath to version manifest tag
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

## Bump patch number, 0.0.X
function bump_patch() {
  local v="$1"

  if [[ "$v" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    printf 'v%s.%s.%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "$((BASH_REMATCH[3] + 1))"
  else
    return 1
  fi
}

## Set version number in versions manifest file
function set_manifest_value() {
  local file="$1" key="$2" value="$3"

  awk -v k="$key" -v v="$value" '
    $1 == k ":" { print k ": " v; next }
    { print }
  ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

base_ref="${GITHUB_EVENT_BEFORE:-}"
head_ref="${GITHUB_SHA:-HEAD}"

if [[ -z "$base_ref" || "$base_ref" == "0000000000000000000000000000000000000000" ]]; then
  base_ref="$(git rev-parse HEAD~1)"
fi

## Detect files changed since last commit
changed_files="$(git diff --name-only --diff-filter=ACMRT "$base_ref" "$head_ref" || true)"

if [[ -z "$changed_files" ]]; then
  echo "No changed files found."
  exit 0
fi

tmp_pairs="$(mktemp)"
trap 'rm -f "$tmp_pairs"' EXIT

cp "$MANIFEST" "${MANIFEST}.work"

## Bump version for changed files
while IFS= read -r path; do
  [[ -z "$path" ]] && continue

  key="$(path_to_key "$path")" || continue

  current="$(awk -v k="$key" '$1 == k ":" {print $2; exit}' "${MANIFEST}.work" || true)"
  [[ -z "$current" ]] && continue

  next="$(bump_patch "$current")" || continue

  set_manifest_value "${MANIFEST}.work" "$key" "$next"
  printf '%s\t%s\t%s\n' "$key" "$current" "$next" >> "$tmp_pairs"
done <<< "$changed_files"

if [[ ! -s "$tmp_pairs" ]]; then
  echo "No releasable changes found."
  rm -f "${MANIFEST}.work"
  exit 0
fi

## Overwrite versions manifest file
mv "${MANIFEST}.work" "$MANIFEST"

if [[ "$DO_TAG" -eq 1 ]]; then
  while IFS=$'\t' read -r key old new; do
    git tag -a "${key}/${new}" -m "${key} ${new}"
  done < "$tmp_pairs"
fi

cat "$tmp_pairs"
