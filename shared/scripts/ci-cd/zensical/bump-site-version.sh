#!/usr/bin/env bash
set -Eeuo pipefail

if ! command -v bump-my-version >/dev/null 2>&1; then
  echo "[ERROR] bump-my-version is not installed or is not on PATH." >&2
  exit 1
fi

debug() {
  printf '[zensical-version-bump] %s\n' "$*"
}

repo_root="$(git rev-parse --show-toplevel)"

version_file="${ZENSICAL_VERSION_FILE:-.version}"
bump_config="${ZENSICAL_BUMP_CONFIG:-.bumpversion.toml}"
changed_paths_file="${ZENSICAL_CHANGED_PATHS_FILE:-}"
changed_paths="${ZENSICAL_CHANGED_PATHS:-}"

resolve_repo_path() {
  local path="$1"

  if [[ "${path}" == /* ]]; then
    realpath -m "${path}"
  else
    realpath -m "${repo_root}/${path}"
  fi
}

version_path="$(resolve_repo_path "${version_file}")"
bump_config_path="$(resolve_repo_path "${bump_config}")"

if [[ ! -f "${version_path}" ]]; then
  echo "[ERROR] Version file not found: ${version_path}" >&2
  exit 1
fi

if [[ ! -f "${bump_config_path}" ]]; then
  echo "[ERROR] bump-my-version config not found: ${bump_config_path}" >&2
  exit 1
fi

paths=()

if [[ -n "${changed_paths_file}" ]]; then
  changed_paths_file_path="$(resolve_repo_path "${changed_paths_file}")"

  if [[ ! -f "${changed_paths_file_path}" ]]; then
    echo "[ERROR] Changed paths file not found: ${changed_paths_file_path}" >&2
    exit 1
  fi

  while IFS= read -r path; do
    [[ -z "${path}" ]] && continue
    [[ "${path}" =~ ^[[:space:]]*# ]] && continue
    paths+=("${path}")
  done <"${changed_paths_file_path}"
fi

if [[ -n "${changed_paths}" ]]; then
  while IFS= read -r path; do
    [[ -z "${path}" ]] && continue
    [[ "${path}" =~ ^[[:space:]]*# ]] && continue
    paths+=("${path}")
  done <<<"${changed_paths}"
fi

if [[ "${#paths[@]}" -eq 0 ]]; then
  paths=(
    "docs/"
    "zensical.toml"
    "mkdocs.yml"
    "mkdocs.yaml"
    "mkdocs.toml"
  )
fi

if git rev-parse -q --verify HEAD^2 >/dev/null 2>&1; then
  mode="merge"
  range="HEAD^1..HEAD^2"
else
  mode="squash-or-linear"
  range="HEAD"
fi

commits="$(git log --format='%s%n%b' "${range}" -- "${paths[@]}" || true)"

debug "repo-root=${repo_root}"
debug "version-file=${version_file}"
debug "bump-config=${bump_config}"
debug "mode=${mode}"
debug "range=${range}"
debug "paths=${paths[*]}"

if [[ -z "$(tr -d '[:space:]' <<<"${commits}")" ]]; then
  debug "No configured Zensical-relevant paths changed; no version bump required."
  printf 'bump-required=false\n'
  printf 'bump-type=\n'
  exit 0
fi

debug "commit-messages:"
while IFS= read -r line; do
  [[ -n "${line}" ]] && debug "  ${line}"
done <<<"${commits}"

bump="patch"
reason="default patch"

if grep -Eq 'BREAKING CHANGE(S)?:|^feat(\(.+\))?!:' <<<"${commits}"; then
  bump="major"
  reason="breaking change detected"
elif grep -Eq '^feat(\(.+\))?:' <<<"${commits}"; then
  bump="minor"
  reason="feat detected"
elif grep -Eq '^fix(\(.+\))?:' <<<"${commits}"; then
  bump="patch"
  reason="fix detected"
fi

debug "decision=bump:${bump}"
debug "reason=${reason}"

bump-my-version bump "${bump}" --config-file "${bump_config_path}"

printf 'bump-required=true\n'
printf 'bump-type=%s\n' "${bump}"
