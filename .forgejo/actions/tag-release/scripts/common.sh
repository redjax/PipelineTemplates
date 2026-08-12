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
  local create_tag="${CREATE_TAG:-false}"
  local delete_tag="${DELETE_TAG:-false}"
  local create_release="${CREATE_RELEASE:-false}"

  [[ -n "${TAG_NAME:-}" ]] || fail "TAG_NAME is required"

  for value in \
    "${create_tag}" \
    "${delete_tag}" \
    "${create_release}"; do
    case "${value}" in
    true | false) ;;
    *)
      fail "Boolean inputs must be either true or false"
      ;;
    esac
  done

  if [[ 
    "${create_tag}" != "true" &&
    "${delete_tag}" != "true" &&
    "${create_release}" != "true" ]] \
    ; then
    fail "At least one of CREATE_TAG, DELETE_TAG, or CREATE_RELEASE must be true"
  fi

  if [[ "${create_tag}" == "true" && "${delete_tag}" == "true" ]]; then
    fail "CREATE_TAG and DELETE_TAG cannot both be true"
  fi

  if [[ "${delete_tag}" == "true" && "${create_release}" == "true" ]]; then
    fail "DELETE_TAG and CREATE_RELEASE cannot both be true"
  fi
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
