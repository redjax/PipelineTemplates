#!/usr/bin/env bash
set -Eeuo pipefail

VERSION_FILE="${VERSION_FILE:-}"
BUMP_TYPE="${BUMP_TYPE:-auto}"
BUMPVERSION_CONFIG="${BUMPVERSION_CONFIG:-}"

find_version_file() {
  local candidates=(
    ".version"
    "VERSION"
    "version"
    "VERSION.txt"
    "version.txt"
  )

  local matches=()

  for candidate in "${candidates[@]}"; do
    if [[ -f "${candidate}" ]]; then
      matches+=("${candidate}")
    fi
  done

  case "${#matches[@]}" in
  0)
    echo "[ERROR] No version file found." >&2
    echo "[ERROR] Specify VERSION_FILE explicitly." >&2
    exit 1
    ;;
  1)
    printf '%s\n' "${matches[0]}"
    ;;
  *)
    echo "[ERROR] Multiple version files found:" >&2
    printf '  %s\n' "${matches[@]}" >&2
    echo "[ERROR] Specify VERSION_FILE explicitly." >&2
    exit 1
    ;;
  esac
}

if [[ -z "${VERSION_FILE}" ]]; then
  VERSION_FILE="$(find_version_file)"
fi

if [[ ! -f "${VERSION_FILE}" ]]; then
  echo "[ERROR] Version file not found: ${VERSION_FILE}" >&2
  exit 1
fi

if [[ -n "${BUMPVERSION_CONFIG}" && ! -f "${BUMPVERSION_CONFIG}" ]]; then
  echo "[ERROR] bump-my-version config not found: ${BUMPVERSION_CONFIG}" >&2
  exit 1
fi

echo "[INFO] Version file: ${VERSION_FILE}"

if [[ -n "${BUMPVERSION_CONFIG}" ]]; then
  echo "[INFO] bump-my-version config: ${BUMPVERSION_CONFIG}"
else
  echo "[INFO] No explicit bump-my-version config supplied"
fi

CURRENT_VERSION="$(tr -d '[:space:]' <"${VERSION_FILE}")"

if [[ -z "${CURRENT_VERSION}" ]]; then
  echo "[ERROR] Version file is empty: ${VERSION_FILE}" >&2
  exit 1
fi

echo "[INFO] Current version: ${CURRENT_VERSION}"

## Automatically determine bump type from commits since the last tag.
if [[ "${BUMP_TYPE}" == "auto" ]]; then
  echo "[INFO] Detecting bump type from git history"

  LAST_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"

  if [[ -n "${LAST_TAG}" ]]; then
    echo "[INFO] Using commits since ${LAST_TAG}"
    COMMITS="$(git log "${LAST_TAG}..HEAD" --pretty=format:%s)"
  else
    echo "[INFO] No previous tag found; using repository history"
    COMMITS="$(git log --pretty=format:%s)"
  fi

  if echo "${COMMITS}" | grep -qiE \
    'BREAKING CHANGE|BREAKING|^[a-z]+(\([^)]*\))?!:'; then

    BUMP_TYPE="major"

  elif echo "${COMMITS}" | grep -qE \
    '^feat(\([^)]*\))?:'; then

    BUMP_TYPE="minor"

  else
    BUMP_TYPE="patch"
  fi
fi

## Validate the selected bump type.
case "${BUMP_TYPE}" in
major | minor | patch) ;;
*)
  echo "[ERROR] Invalid bump type: ${BUMP_TYPE}" >&2
  exit 1
  ;;
esac

echo "[INFO] Selected bump type: ${BUMP_TYPE}"

args=(bump)

if [[ -n "${BUMPVERSION_CONFIG}" ]]; then
  args+=(--config-file "${BUMPVERSION_CONFIG}")
fi

args+=("${BUMP_TYPE}")

bump-my-version "${args[@]}"

## Read and validate the new version.
NEW_VERSION="$(tr -d '[:space:]' <"${VERSION_FILE}")"

if [[ "${CURRENT_VERSION}" == "${NEW_VERSION}" ]]; then
  echo "[ERROR] Version did not change." >&2
  exit 1
fi

echo "current-version=${CURRENT_VERSION}" >>"${FORGEJO_OUTPUT}"
echo "new-version=${NEW_VERSION}" >>"${FORGEJO_OUTPUT}"
echo "bump-type=${BUMP_TYPE}" >>"${FORGEJO_OUTPUT}"
echo "version-file=${VERSION_FILE}" >>"${FORGEJO_OUTPUT}"

echo "[INFO] Version:"
echo "  ${CURRENT_VERSION} -> ${NEW_VERSION}"
