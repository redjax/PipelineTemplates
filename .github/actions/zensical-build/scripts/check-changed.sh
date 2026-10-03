#!/usr/bin/env bash
set -Eeuo pipefail

workspace="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"

to_repo_relative() {
  local path="$1"

  if [[ -z "${path}" ]]; then
    return 0
  fi

  case "${path}" in
  "${workspace}")
    printf '.\n'
    ;;
  "${workspace}/"*)
    printf '%s\n' "${path#"${workspace}/"}"
    ;;
  *)
    echo "[ERROR] Path is outside GITHUB_WORKSPACE: ${path}" >&2
    exit 1
    ;;
  esac
}

working_directory="${ZENSICAL_WORKING_DIRECTORY:?ZENSICAL_WORKING_DIRECTORY is required}"
python_project_dir="${ZENSICAL_PYTHON_PROJECT_DIR:?ZENSICAL_PYTHON_PROJECT_DIR is required}"
zensical_config="${ZENSICAL_CONFIG:-}"
docs_dir="${ZENSICAL_DOCS_DIR:-}"
mode="${CHANGED_PATHS_MODE:-default}"

default_paths=(
  "$(to_repo_relative "${working_directory}")/**"
  "$(to_repo_relative "${python_project_dir}")/pyproject.toml"
  "$(to_repo_relative "${python_project_dir}")/uv.lock"
)

if [[ -n "${zensical_config}" ]]; then
  default_paths+=("$(to_repo_relative "${zensical_config}")")
fi

if [[ -n "${docs_dir}" ]]; then
  default_paths+=("$(to_repo_relative "${docs_dir}")/**")
fi

custom_paths=()
if [[ -n "${CHANGED_PATHS:-}" ]]; then
  while IFS= read -r path; do
    [[ -z "${path}" ]] && continue
    custom_paths+=("${path}")
  done <<<"${CHANGED_PATHS}"
fi

paths=()
case "${mode}" in
default)
  paths=("${default_paths[@]}")
  ;;
replace)
  paths=("${custom_paths[@]}")
  ;;
append)
  paths=("${default_paths[@]}" "${custom_paths[@]}")
  ;;
*)
  echo "[ERROR] Invalid CHANGED_PATHS_MODE: ${mode}" >&2
  exit 1
  ;;
esac

if [[ "${#paths[@]}" -eq 0 ]]; then
  echo "zensical-changed=true" >>"${GITHUB_OUTPUT}"
  echo "[INFO] No change paths configured; build will run."
  exit 0
fi

if ! git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
  echo "zensical-changed=true" >>"${GITHUB_OUTPUT}"
  echo "[INFO] No previous commit is available; build will run."
  exit 0
fi

changed="false"

for path in "${paths[@]}"; do
  if git diff --name-only HEAD~1..HEAD -- "${path}" | grep -q .; then
    changed="true"
    break
  fi
done

echo "zensical-changed=${changed}" >>"${GITHUB_OUTPUT}"
echo "[INFO] zensical-changed=${changed}"

if [[ "${changed}" == "false" ]]; then
  echo "[INFO] Checked paths:"
  printf '  - %s\n' "${paths[@]}"
fi
