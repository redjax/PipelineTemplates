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
python_project_dir="$(normalize_path "${INPUT_PYTHON_PROJECT_DIR:-.}")"
zensical_config="$(normalize_path "${INPUT_ZENSICAL_CONFIG:-}")"
docs_dir="$(normalize_path "${INPUT_DOCS_DIR:-}")"
output_dir="$(normalize_path "${INPUT_OUTPUT_DIR:-site}")"

if [[ ! -d "${working_directory}" ]]; then
  echo "::error::working-directory does not exist: ${working_directory}" >&2
  exit 1
fi

if [[ ! -d "${python_project_dir}" ]]; then
  echo "::error::python-project-dir does not exist: ${python_project_dir}" >&2
  exit 1
fi

if [[ -n "${zensical_config}" && ! -f "${zensical_config}" ]]; then
  echo "::error::zensical-config does not exist: ${zensical_config}" >&2
  exit 1
fi

if [[ -n "${docs_dir}" && ! -d "${docs_dir}" ]]; then
  echo "::error::docs-dir does not exist: ${docs_dir}" >&2
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
  echo "python-project-dir=${python_project_dir}"
  echo "zensical-config=${zensical_config}"
  echo "docs-dir=${docs_dir}"
  echo "output-dir=${output_dir}"
  echo "should-build=${should_build}"
} >>"${GITHUB_OUTPUT}"
