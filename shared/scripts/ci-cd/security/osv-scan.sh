#!/usr/bin/env bash

################################################################
# Run OSV-Scanner against a source repository.                 #
#                                                              #
# This script expects:                                         #
#   - osv-scanner to be available in PATH                      #
#   - to execute from the root of the repository being scanned #
################################################################

set -euo pipefail

function usage() {
  cat <<'EOF'
Usage:
  osv-scan.sh [options]

Options:
  --source <path>
      Source path to scan. Default: .

  --output-file <path>
      Required path for the generated report.

  --format <format>
      Report format. Default: sarif.

  --recursive
      Recursively scan the source path. Default.

  --no-recursive
      Do not recursively scan the source path.

  --config-path <path>
      Optional OSV-Scanner configuration file.

  --no-resolve
      Do not resolve transitive dependencies.

  --allow-no-package-sources
      Treat OSV-Scanner's "No package sources found" result as a successful no-op.

  --verbosity <level>
      OSV-Scanner log verbosity. Default: info.

  --additional-args-file <path>
      Optional file containing additional OSV-Scanner arguments, one argument
      per line. Output/format arguments are rejected because this script owns
      report generation.

  -h, --help
      Display this help text.
EOF
}

source_path="."
output_file=""
output_format="sarif"
recursive=true
config_path=""
no_resolve=false
allow_no_package_sources=false
verbosity="info"
additional_args_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --source)
    source_path="${2:?Missing value for --source}"
    shift 2
    ;;
  --output-file)
    output_file="${2:?Missing value for --output-file}"
    shift 2
    ;;
  --format)
    output_format="${2:?Missing value for --format}"
    shift 2
    ;;
  --recursive)
    recursive=true
    shift
    ;;
  --no-recursive)
    recursive=false
    shift
    ;;
  --allow-no-package-sources)
    allow_no_package_sources=true
    shift
    ;;
  --config-path)
    config_path="${2:?Missing value for --config-path}"
    shift 2
    ;;
  --no-resolve)
    no_resolve=true
    shift
    ;;
  --verbosity)
    verbosity="${2:?Missing value for --verbosity}"
    shift 2
    ;;
  --additional-args-file)
    additional_args_file="${2:?Missing value for --additional-args-file}"
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

if [[ -z "${output_file}" ]]; then
  echo "ERROR: --output-file is required." >&2
  exit 2
fi

if [[ ! -e "${source_path}" ]]; then
  echo "ERROR: Source path does not exist: ${source_path}" >&2
  exit 2
fi

if [[ -n "${config_path}" && ! -f "${config_path}" ]]; then
  echo "ERROR: OSV-Scanner config file does not exist: ${config_path}" >&2
  exit 2
fi

if [[ ! "${output_format}" =~ ^(sarif|json|vertical|table|markdown|html)$ ]]; then
  echo "ERROR: Unsupported report format: ${output_format}" >&2
  exit 2
fi

mkdir --parents "$(dirname "${output_file}")"

args=(
  "--format=${output_format}"
  "--output-file=${output_file}"
  "--verbosity=${verbosity}"
)

if [[ "${recursive}" == "true" ]]; then
  args+=(--recursive)
fi

if [[ -n "${config_path}" ]]; then
  args+=("--config=${config_path}")
fi

if [[ "${no_resolve}" == "true" ]]; then
  args+=(--no-resolve)
fi

if [[ -n "${additional_args_file}" ]]; then
  if [[ ! -f "${additional_args_file}" ]]; then
    echo "ERROR: Additional arguments file does not exist: ${additional_args_file}" >&2
    exit 2
  fi

  while IFS= read -r line || [[ -n "${line}" ]]; do
    argument="${line#"${line%%[![:space:]]*}"}"
    argument="${argument%"${argument##*[![:space:]]}"}"

    [[ -z "${argument}" ]] && continue
    [[ "${argument}" == \#* ]] && continue

    case "${argument}" in
    --format | --format=* | --output | --output=* | --output-file | --output-file=*)
      echo "ERROR: Additional arguments must not override output format or output file: ${argument}" >&2
      exit 2
      ;;
    esac

    args+=("${argument}")
  done <"${additional_args_file}"
fi

args+=("${source_path}")

scan_log="${output_file}.log"

echo "Running OSV-Scanner:"
printf '  %q' osv-scanner "${args[@]}"
echo

set +e

osv-scanner "${args[@]}" 2>&1 | tee "${scan_log}"
scan_exit_code="${PIPESTATUS[0]}"

set -e

if [[ "${scan_exit_code}" == "128" ]] &&
  grep --fixed-strings --quiet \
    "No package sources found" \
    "${scan_log}"; then

  if [[ "${allow_no_package_sources}" == "true" ]]; then
    echo "::notice title=No package sources found::OSV-Scanner found no supported dependency manifest, lockfile, SBOM, or package source. Treating this scan as a successful no-op."
    exit 0
  fi

  echo "::error title=No package sources found::OSV-Scanner found no supported dependency manifest, lockfile, SBOM, or package source."
  exit "${scan_exit_code}"
fi

exit "${scan_exit_code}"
