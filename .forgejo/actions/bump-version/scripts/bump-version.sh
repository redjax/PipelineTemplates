#!/usr/bin/env bash
set -Eeuo pipefail

if [[ -z "${BUMP_TYPE:-}" ]]; then
  echo "[ERROR] BUMP_TYPE is not set" >&2
  exit 1
fi

if [[ -z "${VERSION_FILE:-}" ]]; then
  echo "[ERROR] VERSION_FILE is not set" >&2
  exit 1
fi

if [[ -z "${BUMPVERSION_CONFIG_FILE:-}" ]]; then
  echo "[ERROR] BUMPVERSION_CONFIG_FILE is not set" >&2
  exit 1
fi

if [[ ! -f "${VERSION_FILE}" ]]; then
  echo "[ERROR] Version file not found: ${VERSION_FILE}" >&2
  exit 1
fi

if [[ ! -f "${BUMPVERSION_CONFIG_FILE}" ]]; then
  echo "[ERROR] bump-my-version config not found: ${BUMPVERSION_CONFIG_FILE}" >&2
  exit 1
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

  if [[ -z "${COMMITS}" ]]; then
    echo "[WARN] No commits found; defaulting to patch"
    BUMP_TYPE="patch"

  elif echo "${COMMITS}" | grep -qiE \
    'BREAKING[[:space:]]CHANGE|BREAKING|^[a-z]+(\([^)]*\))?!:'; then

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
  echo "[ERROR] Expected: auto, major, minor, or patch" >&2
  exit 1
  ;;
esac

echo "[INFO] Selected bump type: ${BUMP_TYPE}"
echo "[INFO] Version file: ${VERSION_FILE}"
echo "[INFO] Config file: ${BUMPVERSION_CONFIG_FILE}"

## Perform the bump.
bump-my-version bump \
  --config-file "${BUMPVERSION_CONFIG_FILE}" \
  "${BUMP_TYPE}"

## Read and validate the new version.
NEW_VERSION="$(tr -d '[:space:]' <"${VERSION_FILE}")"

if [[ -z "${NEW_VERSION}" ]]; then
  echo "[ERROR] Version file is empty after bump: ${VERSION_FILE}" >&2
  exit 1
fi

if [[ "${CURRENT_VERSION}" == "${NEW_VERSION}" ]]; then
  echo "[ERROR] Version did not change" >&2
  exit 1
fi

echo "[INFO] Version:"
echo "  ${CURRENT_VERSION} -> ${NEW_VERSION}"

## Export Forgejo Actions outputs.
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "current-version=${CURRENT_VERSION}"
    echo "new-version=${NEW_VERSION}"
    echo "bump-type=${BUMP_TYPE}"
  } >>"${GITHUB_OUTPUT}"
else
  echo "[WARN] GITHUB_OUTPUT is not set; action outputs will not be available"
fi
