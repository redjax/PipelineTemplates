#!/usr/bin/env bash
set -Eeuo pipefail

#########################################################
# Checks whether Astro build-relevant paths changed in  #
# the current commit.                                   #
#                                                       #
# Writes `astro-changed=true|false` to `$GITHUB_OUTPUT` #
#########################################################

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

working_directory="${ASTRO_WORKING_DIRECTORY:?ASTRO_WORKING_DIRECTORY is required}"
astro_project_dir="${ASTRO_PROJECT_DIR:?ASTRO_PROJECT_DIR is required}"
package_lock_file="${ASTRO_PACKAGE_LOCK_FILE:-}"
mode="${CHANGED_PATHS_MODE:-default}"

project_relative="$(to_repo_relative "${astro_project_dir}")"
working_relative="$(to_repo_relative "${working_directory}")"

default_paths=(
  "${project_relative}/src/**"
  "${project_relative}/public/**"
  "${project_relative}/astro.config.*"
  "${project_relative}/package.json"
  "${project_relative}/package-lock.json"
  "${project_relative}/npm-shrinkwrap.json"
  "${project_relative}/pnpm-lock.yaml"
  "${project_relative}/yarn.lock"
  "${project_relative}/tsconfig.json"
  "${project_relative}/tailwind.config.*"
  "${project_relative}/postcss.config.*"
  "${project_relative}/wrangler.json"
  "${project_relative}/wrangler.jsonc"
)

if [[ -n "${package_lock_file}" ]]; then
  package_lock_relative="$(to_repo_relative "${package_lock_file}")"
  default_paths+=("${package_lock_relative}")
fi

if [[ "${working_relative}" == "." ]]; then
  default_paths+=(
    "scripts/astro/**"
    "scripts/install/node.sh"
    "scripts/install/_common.sh"
  )
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
  echo "astro-changed=true" >>"${GITHUB_OUTPUT}"
  echo "[INFO] No change paths configured; build will run."
  exit 0
fi

if ! git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
  echo "astro-changed=true" >>"${GITHUB_OUTPUT}"
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

echo "astro-changed=${changed}" >>"${GITHUB_OUTPUT}"
echo "[INFO] astro-changed=${changed}"

if [[ "${changed}" == "false" ]]; then
  echo "[INFO] Checked paths:"
  printf '  - %s\n' "${paths[@]}"
fi
