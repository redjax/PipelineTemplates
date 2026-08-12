#!/usr/bin/env bash
set -Eeuo pipefail

: "${TAG_NAME:?TAG_NAME is required}"

EXPECTED_TARGET="${EXPECTED_TARGET:-}"
REMOTE="${REMOTE:-origin}"

echo "[INFO] Preparing to delete tag: ${TAG_NAME}"
echo "[INFO] Remote: ${REMOTE}"

git fetch --force --tags "${REMOTE}"

if ! git show-ref --verify --quiet "refs/tags/${TAG_NAME}"; then
  echo "[INFO] Tag does not exist locally after fetch: ${TAG_NAME}"
  echo "[INFO] Nothing to delete."
  exit 0
fi

TAG_SHA="$(git rev-list -n 1 "refs/tags/${TAG_NAME}")"

echo "[INFO] Tag resolves to: ${TAG_SHA}"

if [[ -n "${EXPECTED_TARGET}" ]]; then
  echo "[INFO] Expected target: ${EXPECTED_TARGET}"

  if [[ "${TAG_SHA}" != "${EXPECTED_TARGET}" ]]; then
    echo "[ERROR] Refusing to delete tag ${TAG_NAME}."
    echo "[ERROR] It does not point to the expected workflow commit."
    exit 1
  fi
fi

echo "[INFO] Deleting remote tag: ${TAG_NAME}"

git push "${REMOTE}" ":refs/tags/${TAG_NAME}"

echo "[INFO] Deleting local tag: ${TAG_NAME}"

git tag --delete "${TAG_NAME}"

echo "[INFO] Tag deleted successfully: ${TAG_NAME}"
