#!/usr/bin/env bash
set -euo pipefail

if ! command -v bump-my-version >/dev/null 2>&1; then
  echo "[ERROR] bump-my-version is not installed." >&2
  exit 1
fi

function debug() {
  printf '[version-bump] %s\n' "$*"
}

function collect_commits() {
  git log --format=%s%n%b "$@" -- "${paths[@]}" || true
}

repo_root="$(git rev-parse --show-toplevel)"

## Read site root from env var if it's set & clean path
site_root="${HUGO_SITE_ROOT:-.}"
site_root="${site_root#./}"
site_root="${site_root%/}"
site_root="${site_root:-.}"

config_file="${HUGO_BUMP_CONFIG:-.bumpversion.toml}"
version_file="${HUGO_VERSION_FILE:-.version}"

if [[ "${site_root}" = "." ]]; then
  site_dir="${repo_root}"
else
  site_dir="${repo_root}/${site_root}"
fi

if [[ ! -d "${site_dir}" ]]; then
  echo "[ERROR] site root not found: ${site_root}" >&2
  exit 1
fi

if [[ ! -f "${site_dir}/${config_file}" ]]; then
  echo "[ERROR] config file not found: ${site_dir}/${config_file}" >&2
  exit 1
fi

if [[ ! -f "${site_dir}/${version_file}" ]]; then
  echo "[ERROR] version file not found: ${site_dir}/${version_file}" >&2
  exit 1
fi

cd "${site_dir}"

## Changes to any of these files should trigger a version bump
paths=(
  "archetypes"
  "content"
  "data"
  "i18n"
  "static"
  "hugo.yml"
  "hugo.yaml"
  "hugo.toml"
  "go.mod"
  "go.sum"
)

debug "repo-root=$(git rev-parse --short HEAD)"
debug "site-root=${site_root}"
debug "site-dir=${site_dir}"
debug "config-file=${config_file}"
debug "version-file=${version_file}"

## Determine regular merge or squash merge
if git rev-parse -q --verify HEAD^2 >/dev/null 2>&1; then
  debug "mode=merge"
  debug "range=HEAD^1..HEAD^2"
  commits="$(collect_commits HEAD^1..HEAD^2)"
else
  debug "mode=squash-or-linear"
  debug "range=HEAD"
  commits="$(git show -s --format=%s%n%b HEAD)"
fi

## Print commits that cause a version bump to trigger
debug "messages:"
while IFS= read -r line; do
  [[ -n "$line" ]] && debug "  $line"
done <<<"${commits}"

bump="patch"
reason="default patch"

## Determine bump type
#  Major (X.0.0) = feat!: or any commit with 'BREAKING CHANGES'
#  Minor (0.X.0) = feat: commits
#  Patch (0.0.X) = fix: commits
if grep -Eq 'BREAKING CHANGES|^feat!:' <<<"${commits}"; then
  bump="major"
  reason="breaking change"
elif grep -Eq '^feat(\(.+\))?:' <<<"${commits}"; then
  bump="minor"
  reason="feat detected"
elif grep -Eq '^fix(\(.+\))?:' <<<"${commits}"; then
  bump="patch"
  reason="fix detected"
fi

debug "decision=bump:${bump}"
debug "reason=${reason}"

bump-my-version bump "${bump}" --config-file "${config_file}"
