#!/usr/bin/env bash

#####################################################################
# Discover Go modules and run govulncheck against every module.     #
#                                                                   #
# Expects:                                                          #
#   - govulncheck to be available in PATH                           #
#   - to execute from the root of the repository being scanned      #
#   - jq to be available when combining SARIF reports               #
#####################################################################

set -uo pipefail

repository_root="$(pwd -P)"

function usage() {
  cat <<'EOF'
Usage:
  govulncheck.sh [options]

Options:
  --module-paths-file <path>
      Optional newline-delimited module directories, relative to repository
      root. Each directory must contain go.mod. When omitted, discover every
      go.mod in the repository.

  --exclude-module-paths-file <path>
      Optional newline-delimited module directories to exclude during
      automatic discovery.

  --package-pattern <pattern>
      Go package pattern passed to govulncheck for every module.
      Default: ./...

  --reports-directory <path>
      Directory in which reports are written.
      Default: govulncheck-reports

  --summary-file <path>
      File containing scan result values for CI consumers.
      Default: <reports-directory>/summary.env

  -h, --help
      Display this help text.
EOF
}

module_paths_file=""
exclude_module_paths_file=""
package_pattern="./..."
reports_directory="govulncheck-reports"
summary_file=""
sarif_version="2.1.0"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --module-paths-file)
    module_paths_file="${2:?Missing value for --module-paths-file}"
    shift 2
    ;;
  --exclude-module-paths-file)
    exclude_module_paths_file="${2:?Missing value for --exclude-module-paths-file}"
    shift 2
    ;;
  --package-pattern)
    package_pattern="${2:?Missing value for --package-pattern}"
    shift 2
    ;;
  --reports-directory)
    reports_directory="${2:?Missing value for --reports-directory}"
    shift 2
    ;;
  --summary-file)
    summary_file="${2:?Missing value for --summary-file}"
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "ERROR: Unknown argument: $1" >&2
    usage >&2
    exit 2
    ;;
  esac
done

if ! command -v govulncheck >/dev/null 2>&1; then
  echo "ERROR: govulncheck was not found in PATH." >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq was not found in PATH." >&2
  exit 2
fi

if [[ -n "${module_paths_file}" && ! -f "${module_paths_file}" ]]; then
  echo "ERROR: Module paths file does not exist: ${module_paths_file}" >&2
  exit 2
fi

if [[ -n "${exclude_module_paths_file}" && ! -f "${exclude_module_paths_file}" ]]; then
  echo "ERROR: Exclude module paths file does not exist: ${exclude_module_paths_file}" >&2
  exit 2
fi

if [[ -z "${summary_file}" ]]; then
  summary_file="${reports_directory}/summary.env"
fi

mkdir --parents \
  "${reports_directory}/sarif" \
  "${reports_directory}/text" \
  "${reports_directory}/stderr"

modules_file="$(mktemp)"
excludes_file="$(mktemp)"

function cleanup() {
  rm --force "${modules_file}" "${excludes_file}"
}

trap cleanup EXIT

if [[ -n "${exclude_module_paths_file}" ]]; then
  sed \
    -e 's/\r$//' \
    -e 's/^[[:space:]]*//' \
    -e 's/[[:space:]]*$//' \
    -e '/^$/d' \
    "${exclude_module_paths_file}" |
    sort --unique \
      >"${excludes_file}"
fi

## Normalize explicitly supplied module paths, if any.
#
#  The reusable workflow always creates a temporary file, even when the caller
#  does not provide module-paths. Therefore, an empty or whitespace-only file
#  must mean "use automatic discovery", not "scan no modules".
if [[ -n "${module_paths_file}" ]]; then
  sed \
    -e 's/\r$//' \
    -e 's/^[[:space:]]*//' \
    -e 's/[[:space:]]*$//' \
    -e 's|^\./||' \
    -e '/^$/d' \
    "${module_paths_file}" |
    sed 's|^$|.|' |
    sort --unique \
      >"${modules_file}"
fi

## Use automatic discovery when module-paths was omitted or resolves to no
#  usable module directories.
if [[ ! -s "${modules_file}" ]]; then
  find . \
    -type f \
    -name go.mod \
    -not -path "./.git/*" \
    -not -path "./vendor/*" \
    -not -path "./node_modules/*" \
    -not -path "./.pipeline-templates/*" \
    -printf '%h\n' |
    sed 's|^\./||' |
    sort --unique \
      >"${modules_file}"
fi

echo "Discovered Go modules:"
sed 's/^/  - /' "${modules_file}"

module_count=0
vulnerability_module_count=0
error_module_count=0

if [[ ! -s "${modules_file}" ]]; then
  echo "::notice title=No Go modules found::No go.mod files were discovered."

  cat >"${summary_file}" <<EOF
module_count=0
vulnerability_module_count=0
error_module_count=0
has_vulnerabilities=false
has_errors=false
EOF

  exit 0
fi

while IFS= read -r module_directory; do
  [[ -z "${module_directory}" ]] && continue

  if grep \
    --fixed-strings \
    --line-regexp \
    --quiet \
    "${module_directory}" \
    "${excludes_file}"; then
    echo "Skipping excluded Go module: ${module_directory}"
    continue
  fi

  if [[ ! -f "${module_directory}/go.mod" ]]; then
    echo "::warning title=Missing go.mod::Skipping '${module_directory}'; no go.mod exists there."
    continue
  fi

  module_count=$((module_count + 1))

  if [[ "${module_directory}" == "." ]]; then
    report_id="root"
  else
    report_id="$(
      printf '%s' "${module_directory}" |
        sed 's|/|--|g; s|[^A-Za-z0-9._-]|-|g'
    )"
  fi

  sarif_report="${reports_directory}/sarif/${report_id}.sarif"
  text_report="${reports_directory}/text/${report_id}.txt"
  sarif_stderr="${reports_directory}/stderr/${report_id}-sarif.stderr"
  text_stderr="${reports_directory}/stderr/${report_id}.stderr"

  echo "::group::Govulncheck: ${module_directory}"

  (
    cd "${module_directory}" || exit 1

    govulncheck \
      -format sarif \
      "${package_pattern}" \
      >"${repository_root}/${sarif_report}" \
      2>"${repository_root}/${sarif_stderr}"
  )

  sarif_exit_code=$?

  (
    cd "${module_directory}" || exit 1

    govulncheck \
      "${package_pattern}" \
      >"${repository_root}/${text_report}" \
      2>"${repository_root}/${text_stderr}"
  )

  text_exit_code=$?

  echo "SARIF exit code: ${sarif_exit_code}"
  echo "Text exit code: ${text_exit_code}"

  ## SARIF mode normally exits 0 even when vulnerabilities are present.
  #  Any non-zero SARIF result is treated as a scanner/configuration error.
  if [[ "${sarif_exit_code}" != "0" ]]; then
    error_module_count=$((error_module_count + 1))
    echo "::warning title=Govulncheck SARIF scan failed::Module '${module_directory}' returned exit code ${sarif_exit_code}."
  fi

  ## In normal text mode, exit code 3 means reachable vulnerabilities.
  if [[ "${text_exit_code}" == "3" ]]; then
    vulnerability_module_count=$((vulnerability_module_count + 1))
    echo "::warning title=Reachable Go vulnerabilities found::Module '${module_directory}' contains govulncheck findings."
  elif [[ "${text_exit_code}" != "0" ]]; then
    error_module_count=$((error_module_count + 1))
    echo "::warning title=Govulncheck scan failed::Module '${module_directory}' returned exit code ${text_exit_code}."
  fi

  echo "::endgroup::"
done <"${modules_file}"

shopt -s nullglob
sarif_reports=("${reports_directory}"/sarif/*.sarif)

if [[ ${#sarif_reports[@]} -gt 0 ]]; then
  valid_sarif_reports=()

  for sarif_report in "${sarif_reports[@]}"; do
    if jq --exit-status . "${sarif_report}" >/dev/null 2>&1; then
      valid_sarif_reports+=("${sarif_report}")
    else
      echo "::warning title=Invalid SARIF report::Skipping invalid SARIF file '${sarif_report}'."
      error_module_count=$((error_module_count + 1))
    fi
  done

  if [[ ${#valid_sarif_reports[@]} -gt 0 ]]; then
    if ! jq \
      --slurp \
      --arg sarif_version "${sarif_version}" \
      '
        {
          version: $sarif_version,
          "$schema": (
            "https://json.schemastore.org/sarif-" +
            $sarif_version +
            ".json"
          ),
          runs: [.[].runs[]]
        }
      ' \
      "${valid_sarif_reports[@]}" \
      >"${reports_directory}/govulncheck.sarif"; then
      error_module_count=$((error_module_count + 1))
      echo "::warning title=SARIF merge failed::Could not combine Govulncheck SARIF reports."
      rm --force "${reports_directory}/govulncheck.sarif"
    fi
  fi
fi

has_vulnerabilities=false
has_errors=false

if [[ "${vulnerability_module_count}" -gt 0 ]]; then
  has_vulnerabilities=true
fi

if [[ "${error_module_count}" -gt 0 ]]; then
  has_errors=true
fi

cat >"${summary_file}" <<EOF
module_count=${module_count}
vulnerability_module_count=${vulnerability_module_count}
error_module_count=${error_module_count}
has_vulnerabilities=${has_vulnerabilities}
has_errors=${has_errors}
EOF

echo "Govulncheck summary:"
cat "${summary_file}"
