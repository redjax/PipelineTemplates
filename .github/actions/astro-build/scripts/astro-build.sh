#!/usr/bin/env bash
set -Eeuo pipefail

########################################################
# Builds an Astro site.                                #
#                                                      #
# Environment variables:                               #
#   ASTRO_WORKING_DIRECTORY  (required)                #
#   ASTRO_PROJECT_DIR        (required)                #
#   ASTRO_OUTPUT_DIR         (required)                #
#   ASTRO_BUILD_COMMAND      (default "npm run build") #
#   ASTRO_CLEAN              (default true)            #
#   ASTRO_DEBUG_BUILD        (default false)           #
########################################################

build_env="${ASTRO_BUILD_ENV:-}"
working_directory="${ASTRO_WORKING_DIRECTORY:?ASTRO_WORKING_DIRECTORY is required}"
astro_project_dir="${ASTRO_PROJECT_DIR:?ASTRO_PROJECT_DIR is required}"
output_dir="${ASTRO_OUTPUT_DIR:?ASTRO_OUTPUT_DIR is required}"
build_command="${ASTRO_BUILD_COMMAND:-npm run build}"
clean="${ASTRO_CLEAN:-true}"
debug_build="${ASTRO_DEBUG_BUILD:-false}"

if [[ ! -d "${working_directory}" ]]; then
  echo "[ERROR] Astro working directory does not exist: ${working_directory}" >&2
  exit 1
fi

if [[ ! -d "${astro_project_dir}" ]]; then
  echo "[ERROR] Astro project directory does not exist: ${astro_project_dir}" >&2
  exit 1
fi

if [[ ! -f "${astro_project_dir}/package.json" ]]; then
  echo "[ERROR] Astro project does not contain package.json: ${astro_project_dir}" >&2
  exit 1
fi

if [[ ! -f "${astro_project_dir}/astro.config.mjs" &&
  ! -f "${astro_project_dir}/astro.config.ts" &&
  ! -f "${astro_project_dir}/astro.config.js" &&
  ! -f "${astro_project_dir}/astro.config.cjs" ]]; then
  echo "[ERROR] Astro project does not contain an Astro config file: ${astro_project_dir}" >&2
  exit 1
fi

if [[ "${clean}" == "true" && -d "${output_dir}" ]]; then
  echo "[INFO] Removing existing Astro output: ${output_dir}"
  rm -rf "${output_dir}"
fi

echo "[INFO] Astro working directory: ${working_directory}"
echo "[INFO] Astro project directory: ${astro_project_dir}"
echo "[INFO] Expected output directory: ${output_dir}"
echo "[INFO] Clean output: ${clean}"
echo "[INFO] Debug build: ${debug_build}"

echo
echo "Astro build command:"
printf '  %s\n' "${build_command}"
echo

if [[ "${debug_build}" == "true" ]]; then
  echo "[DEBUG] Node version:"
  node --version

  echo
  echo "[DEBUG] npm version:"
  npm --version

  echo
  echo "[DEBUG] Astro project files:"
  find "${astro_project_dir}" \
    -maxdepth 2 \
    -type f \
    \( \
    -name 'astro.config.*' -o \
    -name 'package.json' -o \
    -name 'package-lock.json' -o \
    -name 'tsconfig.json' -o \
    -name 'tailwind.config.*' -o \
    -name 'wrangler.json*' \
    \) \
    -print |
    sort
fi

if [[ -n "${build_env}" ]]; then
  echo "[INFO] Exporting configured Astro build environment variable names:"

  while IFS= read -r entry; do
    [[ -z "${entry}" ]] && continue
    [[ "${entry}" =~ ^[[:space:]]*# ]] && continue

    if [[ "${entry}" != *=* ]]; then
      echo "[ERROR] Invalid ASTRO_BUILD_ENV entry; expected NAME=value." >&2
      exit 1
    fi

    name="${entry%%=*}"
    value="${entry#*=}"

    if [[ ! "${name}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      echo "[ERROR] Invalid environment variable name: ${name}" >&2
      exit 1
    fi

    export "${name}=${value}"
    echo "[INFO] Exported build environment variable: ${name}"
  done <<<"${ASTRO_BUILD_ENV:-}"
fi

cd "${working_directory}"

if ! bash -o pipefail -c "${build_command}" 2>&1; then
  echo "[ERROR] Failed building Astro site." >&2
  exit 1
fi

if [[ ! -d "${output_dir}" ]]; then
  echo "[ERROR] Astro build did not create expected output directory: ${output_dir}" >&2
  exit 1
fi

if [[ -z "$(find "${output_dir}" -type f -print -quit)" ]]; then
  echo "[ERROR] Astro output directory is empty: ${output_dir}" >&2
  exit 1
fi

echo
echo "[INFO] Astro build completed successfully."
