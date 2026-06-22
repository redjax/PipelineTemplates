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

command -v jq >/dev/null 2>&1 || fail "jq is required"

API_URL="${FJ_URL%/}"
RELEASES_URL="${API_URL}/api/v1/repos/${FJ_REPO}/releases"
TAG_URL="${RELEASES_URL}/tags/${TAG_NAME}"

release_name="${RELEASE_NAME:-$TAG_NAME}"
draft="${DRAFT:-false}"
prerelease="${PRERELEASE:-false}"
target_commitish="${TARGET_COMMITISH:-}"

body_file="$(mktemp)"
trap 'rm -f "$body_file" "$payload"' EXIT

: >"$body_file"
if [[ -n "${RELEASE_NOTES_PATH:-}" ]]; then
  [[ -f "${RELEASE_NOTES_PATH}" ]] || fail "release notes file not found: ${RELEASE_NOTES_PATH}"
  cat "${RELEASE_NOTES_PATH}" >"$body_file"
elif [[ -n "${RELEASE_BODY:-}" ]]; then
  printf '%s' "${RELEASE_BODY}" >"$body_file"
fi

body_text="$(cat "$body_file")"

payload="$(mktemp)"
jq -n \
  --arg tag_name "$TAG_NAME" \
  --arg name "$release_name" \
  --arg body "$body_text" \
  --arg draft "$draft" \
  --arg prerelease "$prerelease" \
  --arg target_commitish "$target_commitish" \
  '
  {
    tag_name: $tag_name,
    name: $name,
    body: $body,
    draft: ($draft == "true"),
    prerelease: ($prerelease == "true")
  }
  + (if $target_commitish != "" then {target_commitish: $target_commitish} else {} end)
  ' >"$payload"

existing_id="$(
  curl -fsS \
    -H "Authorization: token ${FJ_TOKEN}" \
    "${TAG_URL}" |
    jq -r '.id // empty' || true
)"

if [[ -n "${existing_id}" ]]; then
  curl -fsS -X PATCH \
    -H "Authorization: token ${FJ_TOKEN}" \
    -H "Content-Type: application/json" \
    -d @"${payload}" \
    "${RELEASES_URL}/${existing_id}" >/tmp/release.json
else
  curl -fsS -X POST \
    -H "Authorization: token ${FJ_TOKEN}" \
    -H "Content-Type: application/json" \
    -d @"${payload}" \
    "${RELEASES_URL}" >/tmp/release.json
fi

release_id="$(jq -r '.id // empty' /tmp/release.json)"
release_url="$(jq -r '.html_url // empty' /tmp/release.json)"

[[ -n "${release_id}" ]] || fail "Release id missing from response"
[[ -n "${release_url}" ]] || fail "Release url missing from response"

echo "release-id=${release_id}" >>"$GITHUB_OUTPUT"
echo "release-url=${release_url}" >>"$GITHUB_OUTPUT"

echo "[INFO] Release ready: ${release_url}"
