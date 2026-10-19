#!/usr/bin/env bash
set -Eeuo pipefail

workspace="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"

normalize_path() {
  local value="$1"

  if [[ -z "${value}" ]]; then
    printf '\n'
    return 0
  fi

  if [[ "${value}" == /* ]]; then
    realpath -m "${value}"
  else
    realpath -m "${workspace}/${value}"
  fi
}

working_directory="$(normalize_path "${INPUT_WORKING_DIRECTORY:-.}")"
astro_project_dir="$(normalize_path "${INPUT_ASTRO_PROJECT_DIR:-.}")"
output_dir="$(normalize_path "${INPUT_OUTPUT_DIR:-dist}")"
package_lock_file="$(normalize_path "${INPUT_PACKAGE_LOCK_FILE:-}")"

if [[ ! -d "${working_directory}" ]]; then
  echo "::error::working-directory does not exist: ${working_directory}" >&2
  exit 1
fi

if [[ ! -d "${astro_project_dir}" ]]; then
  echo "::error::astro-project-dir does not exist: ${astro_project_dir}" >&2
  exit 1
fi

if [[ ! -f "${astro_project_dir}/package.json" ]]; then
  echo "::error::astro-project-dir does not contain package.json: ${astro_project_dir}" >&2
  exit 1
fi

if [[ ! -f "${astro_project_dir}/astro.config.mjs" &&
  ! -f "${astro_project_dir}/astro.config.ts" &&
  ! -f "${astro_project_dir}/astro.config.js" &&
  ! -f "${astro_project_dir}/astro.config.cjs" ]]; then
  echo "::error::astro-project-dir does not contain an Astro config file: ${astro_project_dir}" >&2
  exit 1
fi

if [[ -n "${package_lock_file}" && ! -f "${package_lock_file}" ]]; then
  echo "::error::package-lock-file does not exist: ${package_lock_file}" >&2
  exit 1
fi

if [[ -z "${output_dir}" ]]; then
  echo "::error::output-dir must not be empty." >&2
  exit 1
fi

if [[ "${output_dir}" != "${workspace}" && "${output_dir}" != "${workspace}/"* ]]; then
  echo "::error::output-dir must remain inside GITHUB_WORKSPACE: ${output_dir}" >&2
  exit 1
fi

should_build="true"
if [[ "${INPUT_CHECK_CHANGED:-false}" == "true" ]]; then
  should_build="false"
fi

{
  echo "working-directory=${working_directory}"
  echo "astro-project-dir=${astro_project_dir}"
  echo "output-dir=${output_dir}"
  echo "package-lock-file=${package_lock_file}"
  echo "should-build=${should_build}"
} >>"${GITHUB_OUTPUT}"
