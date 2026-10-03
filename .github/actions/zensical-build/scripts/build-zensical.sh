#!/usr/bin/env bash
set -Eeuo pipefail

working_directory="${ZENSICAL_WORKING_DIRECTORY:?ZENSICAL_WORKING_DIRECTORY is required}"
python_project_dir="${ZENSICAL_PYTHON_PROJECT_DIR:?ZENSICAL_PYTHON_PROJECT_DIR is required}"
zensical_config="${ZENSICAL_CONFIG:-}"
output_dir="${ZENSICAL_OUTPUT_DIR:?ZENSICAL_OUTPUT_DIR is required}"
clean="${ZENSICAL_CLEAN:-true}"
strict="${ZENSICAL_STRICT:-false}"
build_flags="${ZENSICAL_BUILD_FLAGS:-}"

if [[ ! -d "${working_directory}" ]]; then
  echo "[ERROR] Zensical working directory does not exist: ${working_directory}" >&2
  exit 1
fi

if [[ ! -f "${python_project_dir}/pyproject.toml" ]]; then
  echo "[ERROR] Python project does not contain pyproject.toml: ${python_project_dir}" >&2
  exit 1
fi

if [[ -n "${zensical_config}" && ! -f "${zensical_config}" ]]; then
  echo "[ERROR] Zensical config does not exist: ${zensical_config}" >&2
  exit 1
fi

if [[ "${clean}" == "true" && -d "${output_dir}" ]]; then
  echo "[INFO] Removing existing Zensical output: ${output_dir}"
  rm -rf "${output_dir}"
fi

command=(
  uv
  run
  --project
  "${python_project_dir}"
  zensical
  build
)

if [[ -n "${zensical_config}" ]]; then
  command+=(--config-file "${zensical_config}")
fi

if [[ "${clean}" == "true" ]]; then
  command+=(--clean)
fi

if [[ "${strict}" == "true" ]]; then
  command+=(--strict)
fi

if [[ -n "${build_flags}" ]]; then
  read -r -a extra_flags <<<"${build_flags}"
  command+=("${extra_flags[@]}")
fi

echo "[INFO] Zensical working directory: ${working_directory}"
echo "[INFO] UV project directory: ${python_project_dir}"
echo "[INFO] Zensical config: ${zensical_config:-<auto-discover>}"
echo "[INFO] Expected output directory: ${output_dir}"

echo
echo "Zensical command:"
printf '  %q ' "${command[@]}"
echo

cd "${working_directory}"
if ! "${command[@]}" 2>&1; then
  echo "[ERROR] Failed building Zensical site." >&2
  exit 1
else
  echo
  echo "[INFO] Zensical build completed successfully."
fi
