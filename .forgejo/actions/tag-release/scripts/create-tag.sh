#!/usr/bin/env bash
set -euo pipefail

function fail() {
  echo "[ERROR] $*" >&2
  exit 1
}

: "${TAG_NAME:?Missing TAG_NAME}"
: "${GIT_USER_NAME:=forgejo-actions}"
: "${GIT_USER_EMAIL:=forgejo-actions@localhost}"

git config user.name "${GIT_USER_NAME}"
git config user.email "${GIT_USER_EMAIL}"

if git show-ref --verify --quiet "refs/tags/${TAG_NAME}"; then
  echo "[INFO] Tag ${TAG_NAME} already exists"
  exit 0
fi

if [[ -n "${TAG_MESSAGE:-}" ]]; then
  git tag -a "${TAG_NAME}" -m "${TAG_MESSAGE}"
else
  git tag "${TAG_NAME}"
fi

git push origin "${TAG_NAME}"
echo "[INFO] Created tag ${TAG_NAME}"
