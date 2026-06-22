#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-}"

function fail() {
  echo "[ERROR] $*" >&2
  exit 1
}

function require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || fail "Missing required env var: ${name}"
}

function validate_inputs() {
  [[ -n "${TAG_NAME:-}" ]] || fail "TAG_NAME is required"
  [[ "${CREATE_TAG:-false}" == "true" || "${CREATE_RELEASE:-false}" == "true" ]] || fail "At least one of CREATE_TAG or CREATE_RELEASE must be true"
}

function resolve_release_notes() {
  local out="/tmp/release-notes.txt"
  : >"$out"

  if [[ -n "${RELEASE_NOTES_PATH:-}" ]]; then
    [[ -f "${RELEASE_NOTES_PATH}" ]] || fail "release notes file not found: ${RELEASE_NOTES_PATH}"
    cat "${RELEASE_NOTES_PATH}" >"$out"
  else
    printf '%s' "${RELEASE_BODY:-}" >"$out"
  fi

  echo "$out"
}

case "$cmd" in
validate)
  validate_inputs
  ;;
notes)
  resolve_release_notes
  ;;
*)
  fail "Usage: $0 {validate|notes}"
  ;;
esac
