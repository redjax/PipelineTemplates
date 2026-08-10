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

## Normalize Forgejo URL. Remove /v1/api.
API_URL="${FJ_URL%/}"
API_URL="${API_URL%/api/v1}"

REPO_URL="${API_URL}/api/v1/repos/${FJ_REPO}"
RELEASES_URL="${REPO_URL}/releases"
TAG_URL="${RELEASES_URL}/tags/${TAG_NAME}"

echo "[DEBUG] FJ_URL=${FJ_URL}"
echo "[DEBUG] API_URL=${API_URL}"
echo "[DEBUG] FJ_REPO=${FJ_REPO}"
echo "[DEBUG] TAG_NAME=${TAG_NAME}"
echo "[DEBUG] REPO_URL=${REPO_URL}"
echo "[DEBUG] RELEASES_URL=${RELEASES_URL}"
echo "[DEBUG] TAG_URL=${TAG_URL}"

repo_probe_file="${tmp_dir}/repo-probe.json"
repo_status="$(
  curl \
    --silent \
    --show-error \
    --output "${repo_probe_file}" \
    --write-out "%{http_code}" \
    --header "Authorization: token ${FJ_TOKEN}" \
    --header "Accept: application/json" \
    "${REPO_URL}"
)"

echo "[DEBUG] Repo probe HTTP status=${repo_status}"

if [[ "${repo_status}" != "200" ]]; then
  echo "[DEBUG] Repo probe response:"
  cat "${repo_probe_file}" >&2 || true
  fail "Repo probe failed with HTTP ${repo_status}"
fi

release_name="${RELEASE_NAME:-${TAG_NAME}}"
draft="${DRAFT:-false}"
prerelease="${PRERELEASE:-false}"
target_commitish="${TARGET_COMMITISH:-}"

body_file="${tmp_dir}/release-body.txt"
payload_file="${tmp_dir}/release-payload.json"
response_file="${tmp_dir}/release-response.json"

: >"${body_file}"

if [[ -n "${RELEASE_NOTES_PATH:-}" ]]; then
  [[ -f "${RELEASE_NOTES_PATH}" ]] ||
    fail "Release notes file not found: ${RELEASE_NOTES_PATH}"

  cat "${RELEASE_NOTES_PATH}" >"${body_file}"
elif [[ -n "${RELEASE_BODY:-}" ]]; then
  printf '%s' "${RELEASE_BODY}" >"${body_file}"
fi

body_text="$(cat "${body_file}")"

jq -n \
  --arg tag_name "${TAG_NAME}" \
  --arg name "${release_name}" \
  --arg body "${body_text}" \
  --arg draft "${draft}" \
  --arg prerelease "${prerelease}" \
  --arg target_commitish "${target_commitish}" \
  '
  {
    tag_name: $tag_name,
    name: $name,
    body: $body,
    draft: ($draft == "true"),
    prerelease: ($prerelease == "true")
  }
  + (
    if $target_commitish != ""
    then { target_commitish: $target_commitish }
    else {}
    end
  )
  ' >"${payload_file}"

tag_lookup_file="${tmp_dir}/tag-lookup.json"
tag_lookup_status="$(
  curl \
    --silent \
    --show-error \
    --output "${tag_lookup_file}" \
    --write-out "%{http_code}" \
    --header "Authorization: token ${FJ_TOKEN}" \
    --header "Accept: application/json" \
    "${TAG_URL}"
)"

echo "[DEBUG] Tag lookup HTTP status=${tag_lookup_status}"

if [[ "${tag_lookup_status}" == "200" ]]; then
  existing_id="$(jq -r '.id // empty' "${tag_lookup_file}")"
else
  existing_id=""
fi

if [[ -n "${existing_id}" ]]; then
  echo "[INFO] Updating existing release ID: ${existing_id}"

  curl \
    --fail-with-body \
    --silent \
    --show-error \
    --request PATCH \
    --header "Authorization: token ${FJ_TOKEN}" \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --data @"${payload_file}" \
    --output "${response_file}" \
    "${RELEASES_URL}/${existing_id}"
else
  echo "[INFO] Creating release for tag: ${TAG_NAME}"

  curl \
    --fail-with-body \
    --silent \
    --show-error \
    --request POST \
    --header "Authorization: token ${FJ_TOKEN}" \
    --header "Accept: application/json" \
    --header "Content-Type: application/json" \
    --data @"${payload_file}" \
    --output "${response_file}" \
    "${RELEASES_URL}"
fi

release_id="$(jq -r '.id // empty' "${response_file}")"
release_url="$(jq -r '.html_url // empty' "${response_file}")"

[[ -n "${release_id}" ]] ||
  fail "Release ID missing from Forgejo response"

[[ -n "${release_url}" ]] ||
  fail "Release URL missing from Forgejo response"

echo "release-id=${release_id}" >>"${GITHUB_OUTPUT}"
echo "release-url=${release_url}" >>"${GITHUB_OUTPUT}"

echo "[INFO] Release ready: ${release_url}"
