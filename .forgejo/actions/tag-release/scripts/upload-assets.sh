#!/usr/bin/env bash
set -Eeuo pipefail

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

command -v curl >/dev/null 2>&1 || fail "curl is required"
command -v jq >/dev/null 2>&1 || fail "jq is required"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

## Normalize Forgejo URL. Remove /api/v1 string.
API_URL="${FJ_URL%/}"
API_URL="${API_URL%/api/v1}"

RELEASE_URL="${API_URL}/api/v1/repos/${FJ_REPO}/releases/tags/${TAG_NAME}"
OVERWRITE_ASSETS="${OVERWRITE_ASSETS:-false}"

echo "[DEBUG] FJ_URL=${FJ_URL}"
echo "[DEBUG] API_URL=${API_URL}"
echo "[DEBUG] FJ_REPO=${FJ_REPO}"
echo "[DEBUG] TAG_NAME=${TAG_NAME}"
echo "[DEBUG] RELEASE_URL=${RELEASE_URL}"
echo "[DEBUG] OVERWRITE_ASSETS=${OVERWRITE_ASSETS}"

release_file="${tmp_dir}/release.json"

curl \
  --fail-with-body \
  --silent \
  --show-error \
  --header "Authorization: token ${FJ_TOKEN}" \
  --header "Accept: application/json" \
  --output "${release_file}" \
  "${RELEASE_URL}"

release_id="$(jq -r '.id // empty' "${release_file}")"

[[ -n "${release_id}" ]] ||
  fail "Release ID missing from Forgejo response"

assets_url="${API_URL}/api/v1/repos/${FJ_REPO}/releases/${release_id}/assets"

files=()

if [[ -n "${ASSET_GLOB:-}" ]]; then
  shopt -s nullglob

  for file in ${ASSET_GLOB}; do
    [[ -f "${file}" ]] && files+=("${file}")
  done
elif [[ -n "${ARTIFACT_PATH:-}" ]]; then
  if [[ -d "${ARTIFACT_PATH}" ]]; then
    while IFS= read -r -d '' file; do
      files+=("${file}")
    done < <(
      find "${ARTIFACT_PATH}" \
        -maxdepth 1 \
        -type f \
        -print0
    )
  elif [[ -f "${ARTIFACT_PATH}" ]]; then
    files+=("${ARTIFACT_PATH}")
  else
    fail "Artifact path does not exist: ${ARTIFACT_PATH}"
  fi
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "[INFO] No assets found to upload."
  exit 0
fi

uploaded=0

for file in "${files[@]}"; do
  [[ -f "${file}" ]] || continue

  name="$(basename "${file}")"
  encoded_name="$(jq -rn --arg value "${name}" '$value | @uri')"

  echo "[INFO] Preparing asset: ${name}"

  existing_asset_id="$(
    curl \
      --fail-with-body \
      --silent \
      --show-error \
      --header "Authorization: token ${FJ_TOKEN}" \
      --header "Accept: application/json" \
      "${assets_url}" |
      jq -r \
        --arg name "${name}" \
        '.[] | select(.name == $name) | .id' |
      head -n 1
  )"

  if [[ -n "${existing_asset_id}" && "${existing_asset_id}" != "null" ]]; then
    if [[ "${OVERWRITE_ASSETS}" != "true" ]]; then
      fail "Release asset already exists: ${name}"
    fi

    echo "[INFO] Deleting existing release asset: ${name}"

    curl \
      --fail-with-body \
      --silent \
      --show-error \
      --request DELETE \
      --header "Authorization: token ${FJ_TOKEN}" \
      "${assets_url}/${existing_asset_id}"
  fi

  echo "[INFO] Uploading asset: ${name}"

  curl \
    --fail-with-body \
    --silent \
    --show-error \
    --request POST \
    --header "Authorization: token ${FJ_TOKEN}" \
    --header "Content-Type: application/octet-stream" \
    --data-binary @"${file}" \
    "${assets_url}?name=${encoded_name}"

  uploaded=$((uploaded + 1))
done

echo "[INFO] Uploaded ${uploaded} asset(s)."
