#!/usr/bin/env bash
set -euo pipefail

function fail() {
  echo "[ERROR] $*" >&2
  exit 1
}

function require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || fail "Missing required env var: ${name}"
}

require_env FJ_URL
require_env FJ_REPO
require_env FJ_TOKEN
require_env TAG_NAME

API_URL="${FJ_URL%/}"
RELEASE_URL="${API_URL}/api/v1/repos/${FJ_REPO}/releases/tags/${TAG_NAME}"

release_id="$(
  curl -fsS \
    -H "Authorization: token ${FJ_TOKEN}" \
    "${RELEASE_URL}" | python3 -c 'import sys, json; print(json.load(sys.stdin)["id"])'
)"

files=()

if [[ -n "${ASSET_GLOB:-}" ]]; then
  shopt -s nullglob
  for f in ${ASSET_GLOB}; do
    files+=("$f")
  done
else
  if [[ -n "${ARTIFACT_PATH:-}" ]]; then
    if [[ -d "${ARTIFACT_PATH}" ]]; then
      while IFS= read -r -d '' f; do
        files+=("$f")
      done < <(find "${ARTIFACT_PATH}" -maxdepth 1 -type f -print0)
    elif [[ -f "${ARTIFACT_PATH}" ]]; then
      files+=("${ARTIFACT_PATH}")
    fi
  fi
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "[INFO] No assets found to upload"
  exit 0
fi

for file in "${files[@]}"; do
  [[ -f "$file" ]] || continue
  name="$(basename "$file")"
  echo "[INFO] Uploading ${name}"
  curl -fsS -X POST \
    -H "Authorization: token ${FJ_TOKEN}" \
    -H "Content-Type: application/octet-stream" \
    --data-binary @"${file}" \
    "${API_URL}/api/v1/repos/${FJ_REPO}/releases/${release_id}/assets?name=${name}"
done

echo "[INFO] Uploaded ${#files[@]} asset(s)"
