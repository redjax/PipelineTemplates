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

export RELEASE_NAME="${RELEASE_NAME:-$TAG_NAME}"
export DRAFT="${DRAFT:-false}"
export PRERELEASE="${PRERELEASE:-false}"
export TARGET_COMMITISH="${TARGET_COMMITISH:-}"

BODY_FILE="/tmp/release-notes.txt"
: >"$BODY_FILE"
if [[ -n "${RELEASE_NOTES_PATH:-}" ]]; then
  [[ -f "${RELEASE_NOTES_PATH}" ]] || fail "release notes file not found: ${RELEASE_NOTES_PATH}"
  cat "${RELEASE_NOTES_PATH}" >"$BODY_FILE"
elif [[ -n "${RELEASE_BODY:-}" ]]; then
  printf '%s' "${RELEASE_BODY}" >"$BODY_FILE"
fi

payload="$(mktemp)"
python3 - <<PY >"$payload"
import json, os, pathlib
data = {
  "tag_name": os.environ["TAG_NAME"],
  "name": os.environ["RELEASE_NAME"],
  "body": pathlib.Path("/tmp/release-notes.txt").read_text(),
  "draft": os.environ["DRAFT"].lower() == "true",
  "prerelease": os.environ["PRERELEASE"].lower() == "true",
}
if os.environ.get("TARGET_COMMITISH"):
  data["target_commitish"] = os.environ["TARGET_COMMITISH"]
print(json.dumps(data))
PY

existing_id="$(
  curl -fsS \
    -H "Authorization: token ${FJ_TOKEN}" \
    "${TAG_URL}" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("id",""))' || true
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

release_id="$(python3 -c 'import json; print(json.load(open("/tmp/release.json")).get("id",""))')"
release_url="$(python3 -c 'import json; print(json.load(open("/tmp/release.json")).get("html_url",""))')"

[[ -n "${release_id}" ]] || fail "Release id missing from response"
[[ -n "${release_url}" ]] || fail "Release url missing from response"

echo "release-id=${release_id}" >>"$GITHUB_OUTPUT"
echo "release-url=${release_url}" >>"$GITHUB_OUTPUT"

echo "[INFO] Release ready: ${release_url}"
