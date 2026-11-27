#!/usr/bin/env bash
#
# Run `go test` and publish a summary. Configured through the environment
# variables set in action.yml.
set -Eeuo pipefail

MODULE_DIR="${MODULE_DIR:-.}"
PACKAGES="${PACKAGES:-./...}"
RACE="${RACE:-false}"
SHORT="${SHORT:-false}"
VERBOSE="${VERBOSE:-false}"
COUNT="${COUNT:-}"
SHUFFLE="${SHUFFLE:-false}"
TIMEOUT="${TIMEOUT:-}"
BUILD_TAGS="${BUILD_TAGS:-}"
COVERAGE="${COVERAGE:-false}"
COVERAGE_THRESHOLD="${COVERAGE_THRESHOLD:-}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
OUTPUT_DIR="${OUTPUT_DIR:-test-results}"

log() { printf '[INFO] %s\n' "$*"; }
fail() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

[[ -d "${MODULE_DIR}" ]] || fail "module-dir does not exist: ${MODULE_DIR}"
cd "${MODULE_DIR}"

[[ -f go.mod ]] || fail "no go.mod found in ${MODULE_DIR}"
command -v go >/dev/null || fail "go is not on PATH; run the setup-go action first"

if [[ -n "${COVERAGE_THRESHOLD}" ]]; then
  [[ "${COVERAGE_THRESHOLD}" =~ ^[0-9]+([.][0-9]+)?$ ]] ||
    fail "coverage-threshold must be a number, got: ${COVERAGE_THRESHOLD}"
  COVERAGE="true"
fi

mkdir -p "${OUTPUT_DIR}"
OUTPUT_DIR="$(cd "${OUTPUT_DIR}" && pwd)"
log_file="${OUTPUT_DIR}/go-test.log"
profile="${OUTPUT_DIR}/coverage.out"

args=(test)

if [[ "${VERBOSE}" == "true" ]]; then args+=(-v); fi
if [[ "${SHORT}" == "true" ]]; then args+=(-short); fi
if [[ "${SHUFFLE}" == "true" ]]; then args+=(-shuffle=on); fi
if [[ -n "${COUNT}" ]]; then args+=("-count=${COUNT}"); fi
if [[ -n "${TIMEOUT}" ]]; then args+=("-timeout=${TIMEOUT}"); fi
if [[ -n "${BUILD_TAGS}" ]]; then args+=("-tags=${BUILD_TAGS}"); fi

if [[ "${RACE}" == "true" ]]; then
  export CGO_ENABLED=1
  args+=(-race)
fi

if [[ "${COVERAGE}" == "true" ]]; then
  args+=("-coverprofile=${profile}" -covermode=atomic)
fi

if [[ -n "${EXTRA_ARGS}" ]]; then
  read -r -a extra <<<"${EXTRA_ARGS}"
  args+=("${extra[@]}")
fi

read -r -a pkgs <<<"${PACKAGES}"

log "$(go version)"
log "go ${args[*]} ${pkgs[*]}"

set +e
go "${args[@]}" "${pkgs[@]}" 2>&1 | tee "${log_file}"
status="${PIPESTATUS[0]}"
set -e

count_matches() { grep -cE "$1" "${log_file}" || true; }

ok_pkgs="$(count_matches '^ok[[:space:]]')"
failed_pkgs="$(count_matches '^FAIL[[:space:]]+[^[:space:]]')"
untested_pkgs="$(count_matches '^\?[[:space:]]')"

mapfile -t failed_tests < <(
  grep -E '^[[:space:]]*--- FAIL:' "${log_file}" |
    sed -E 's/^[[:space:]]*--- FAIL: ([^ ]+).*/\1/' |
    sort -u || true
)

coverage_pct=""
if [[ "${COVERAGE}" == "true" && -s "${profile}" ]]; then
  if go tool cover -func="${profile}" >"${OUTPUT_DIR}/coverage.txt" &&
    go tool cover -html="${profile}" -o "${OUTPUT_DIR}/coverage.html"; then
    coverage_pct="$(awk '/^total:/ { print $NF }' "${OUTPUT_DIR}/coverage.txt")"
  else
    log "could not build the coverage report"
  fi
fi

threshold_failed="false"
if [[ "${status}" -eq 0 && -n "${COVERAGE_THRESHOLD}" ]]; then
  if [[ -z "${coverage_pct}" ]]; then
    threshold_failed="true"
  elif ! awk -v actual="${coverage_pct%\%}" -v min="${COVERAGE_THRESHOLD}" \
    'BEGIN { exit !(actual + 0 >= min + 0) }'; then
    threshold_failed="true"
  fi
fi

result="passed"
if [[ "${status}" -ne 0 || "${threshold_failed}" == "true" ]]; then
  result="failed"
fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## Go test results"
    echo
    echo "| | |"
    echo "|---|---|"
    echo "| Result | ${result} |"
    echo "| Packages passed | ${ok_pkgs} |"
    echo "| Packages failed | ${failed_pkgs} |"
    echo "| Packages without tests | ${untested_pkgs} |"
    if [[ "${COVERAGE}" == "true" ]]; then
      echo "| Coverage | ${coverage_pct:-n/a} |"
      if [[ -n "${COVERAGE_THRESHOLD}" ]]; then
        echo "| Coverage threshold | ${COVERAGE_THRESHOLD}% |"
      fi
    fi
    echo
    echo '```text'
    echo "go ${args[*]} ${pkgs[*]}"
    echo '```'

    if [[ "${#failed_tests[@]}" -gt 0 && -n "${failed_tests[0]}" ]]; then
      echo
      echo "### Failed tests"
      echo
      printf -- '- `%s`\n' "${failed_tests[@]:0:50}"
      if [[ "${#failed_tests[@]}" -gt 50 ]]; then
        echo "- ...and $((${#failed_tests[@]} - 50)) more"
      fi
    fi
  } >>"${GITHUB_STEP_SUMMARY}"
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "result=${result}"
    echo "coverage=${coverage_pct}"
    echo "output-dir=${OUTPUT_DIR}"
  } >>"${GITHUB_OUTPUT}"
fi

if [[ "${status}" -ne 0 ]]; then
  printf '[ERROR] go test failed (exit %s)\n' "${status}" >&2
  exit "${status}"
fi

if [[ "${threshold_failed}" == "true" ]]; then
  fail "coverage ${coverage_pct:-unavailable} is below the ${COVERAGE_THRESHOLD}% threshold"
fi

log "tests passed${coverage_pct:+, coverage ${coverage_pct}}"
