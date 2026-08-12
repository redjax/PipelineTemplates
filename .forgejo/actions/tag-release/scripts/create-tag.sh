#!/usr/bin/env bash
set -Eeuo pipefail

function fail() {
  echo "[ERROR] $*" >&2
  exit 1
}

: "${TAG_NAME:?Missing TAG_NAME}"

GIT_USER_NAME="${GIT_USER_NAME:-forgejo-actions}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-forgejo-actions}"
REMOTE="${REMOTE:-origin}"

git config user.name "${GIT_USER_NAME}"
git config user.email "${GIT_USER_EMAIL}"

echo "[INFO] Fetching tags from ${REMOTE}"

git fetch --force --tags "${REMOTE}"

head_sha="$(git rev-parse HEAD)"

if git show-ref --verify --quiet "refs/tags/${TAG_NAME}"; then
  tag_sha="$(git rev-list -n 1 "refs/tags/${TAG_NAME}")"

  echo "[INFO] Tag already exists: ${TAG_NAME}"
  echo "[INFO] Tag commit: ${tag_sha}"
  echo "[INFO] HEAD commit: ${head_sha}"

  if [[ "${tag_sha}" != "${head_sha}" ]]; then
    fail "Existing tag ${TAG_NAME} does not point to the current commit"
  fi

  echo "[INFO] Existing tag points to the current commit; reusing it."
  exit 0
fi

if [[ -n "${TAG_MESSAGE:-}" ]]; then
  git tag \
    --annotate \
    "${TAG_NAME}" \
    --message "${TAG_MESSAGE}"
else
  git tag "${TAG_NAME}"
fi

git push "${REMOTE}" "refs/tags/${TAG_NAME}"

echo "[INFO] Created tag: ${TAG_NAME}"
echo "[INFO] Tag commit: ${head_sha}"
