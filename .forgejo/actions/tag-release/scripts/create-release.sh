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
RELEASES_URL="${API_URL}/api/v1/repos/${FJ_REPO}/releases"
TAG_URL="${RELEASES_URL}/tags/${TAG_NAME}"

release_notes_file="${RELEASE_NOTES_PATH:-}"
if [[ -z "${release_notes_file}" && -n "${RELEASE_BODY:-}" ]]; then
  release_notes_file="$(mktemp)"
  printf '%s' "${RELEASE_BODY}" >"${release_notes_file}"
fi

release_name="${RELEASE_NAME:-$TAG_NAME}"
draft="${DRAFT:-false}"
prerelease="${PRERELEASE:-false}"
target_commitish="${TARGET_COMMITISH:-}"

payload="$(mktemp)"
python3 - <<PY >"${payload}"
import json, os
data = {
  "tag_name": os.environ["TAG_NAME"],
  "name": os.environ["RELEASE_NAME"],
  "draft": os.environ["DRAFT"].lower() == "true",
  "prerelease": os.environ["PRERELEASE"].lower() == "true",
}
if os.environ.get("TARGET_COMMITISH"):
  data["target_commitish"] = os.environ["TARGET_COMMITISH"]
print(json.dumps(data))
PY

if curl -fsS -H "Authorization: token ${FJ_TOKEN}" "${TAG_URL}" >/tmp/release.json; then
  release_id="$(python3 -c 'import json; print(json.load(open("/tmp/release.json")).get("id",""))')"
  if [[ -z "${release_id}" ]]; then
    fail "Could not determine existing release id"
  fi
  curl -fsS -X PATCH \
    -H "Authorization: token ${FJ_TOKEN}" \
    -H "Content-Type: application/json" \
    -d @"${payload}" \
    "${RELEASES_URL}/${release_id}" >/tmp/release.json
else
  export TAG_NAME
  export RELEASE_NAME="${release_name}"
  export DRAFT="${draft}"
  export PRERELEASE="${prerelease}"
  export TARGET_COMMITISH="${target_commitish}"
  curl -fsS -X POST \
    -H "Authorization: token ${FJ_TOKEN}" \
    -H "Content-Type: application/json" \
    -d @"${payload}" \
    "${RELEASES_URL}" >/tmp/release.json
fi

release_id="$(python3 -c 'import json; print(json.load(open("/tmp/release.json")).get("id",""))')"
release_url="$(python3 -c 'import json; print(json.load(open("/tmp/release.json")).get("html_url",""))')"

[[ -n "${release_id}" ]] || fail "Release id missing from response"
[[ -n "${release_url}" ]] || fail "Release url missing from response"

echo "release-id=${release_id}" >>"$GITHUB_OUTPUT"
echo "release-url=${release_url}" >>"$GITHUB_OUTPUT"

echo "[INFO] Release ready: ${release_url}"
