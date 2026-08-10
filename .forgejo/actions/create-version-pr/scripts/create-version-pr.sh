#!/usr/bin/env bash
set -Eeuo pipefail

: "${VERSION:?VERSION is required}"
: "${BASE_BRANCH:?BASE_BRANCH is required}"
: "${BRANCH_PREFIX:?BRANCH_PREFIX is required}"
: "${API_URL:?API_URL is required}"
: "${REPOSITORY:?REPOSITORY is required}"
: "${TOKEN:?TOKEN is required}"

BRANCH="${BRANCH_PREFIX}${VERSION}"

## Normalize the API URL.
API_URL="${API_URL%/}"

if [[ "${API_URL}" != */api/v1 ]]; then
  echo "[ERROR] Forgejo endpoint must end with /api/v1"
  echo "Got: ${API_URL}"
  exit 1
fi

echo "[INFO] Version: ${VERSION}"
echo "[INFO] Base branch: ${BASE_BRANCH}"
echo "[INFO] Version branch: ${BRANCH}"
echo "[INFO] Repository: ${REPOSITORY}"
echo "[INFO] Forgejo API: ${API_URL}"

git config user.name "${GIT_USER_NAME:-forgejo-actions}"
git config user.email "${GIT_USER_EMAIL:-forgejo-actions@localhost}"

## Make sure we are starting from the latest base branch.
echo "[INFO] Fetching ${BASE_BRANCH}"

git fetch origin \
  "${BASE_BRANCH}:${BASE_BRANCH}" \
  --tags

git checkout "${BASE_BRANCH}"
git reset --hard "origin/${BASE_BRANCH}"

## Create or reset the version bump branch.
if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  echo "[INFO] Local branch already exists: ${BRANCH}"
  git branch -D "${BRANCH}"
fi

git checkout -b "${BRANCH}"

## Stage version-related files.
#
#  This intentionally stages only the files associated with the version bump.
git add .version .bumpversion.toml

if git diff --cached --quiet; then
  echo "[ERROR] No version files changed"
  exit 1
fi

## Commit the version bump.
git commit \
  -m "chore: bump version to ${VERSION}"

## Push the branch.
echo "[INFO] Pushing branch: ${BRANCH}"

git push \
  --set-upstream \
  origin \
  "${BRANCH}"

echo "[INFO] Branch pushed: ${BRANCH}"

## Look for an existing open PR from this branch.
echo "[INFO] Checking for existing pull request"

EXISTING_PR="$(
  curl \
    --fail \
    --silent \
    --show-error \
    --header "Authorization: token ${TOKEN}" \
    --header "Accept: application/json" \
    "${API_URL}/repos/${REPOSITORY}/pulls?state=open" |
    jq -r \
      --arg branch "${BRANCH}" \
      '.[] | select(.head.ref == $branch) | .number' |
    head -n 1
)"

if [[ -n "${EXISTING_PR}" && "${EXISTING_PR}" != "null" ]]; then
  PR_NUMBER="${EXISTING_PR}"

  echo "[INFO] Existing PR found: #${PR_NUMBER}"
else
  echo "[INFO] Creating pull request"

  RESPONSE="$(
    curl \
      --fail \
      --silent \
      --show-error \
      --request POST \
      --header "Authorization: token ${TOKEN}" \
      --header "Accept: application/json" \
      --header "Content-Type: application/json" \
      "${API_URL}/repos/${REPOSITORY}/pulls" \
      --data "$(jq -n \
        --arg title "chore: bump version to ${VERSION}" \
        --arg body "Automated version bump to ${VERSION}." \
        --arg head "${BRANCH}" \
        --arg base "${BASE_BRANCH}" \
        '{
                    title: $title,
                    body: $body,
                    head: $head,
                    base: $base
                }')"
  )"

  PR_NUMBER="$(echo "${RESPONSE}" | jq -r '.number')"

  if [[ -z "${PR_NUMBER}" || "${PR_NUMBER}" == "null" ]]; then
    echo "[ERROR] Failed to create pull request"
    echo "${RESPONSE}"
    exit 1
  fi

  echo "[INFO] Created PR #${PR_NUMBER}"
fi

## Return action outputs.
echo "branch=${BRANCH}" >>"${GITHUB_OUTPUT}"
echo "pr-number=${PR_NUMBER}" >>"${GITHUB_OUTPUT}"

echo "[INFO] Version bump PR ready:"
echo "  Branch: ${BRANCH}"
echo "  PR:     #${PR_NUMBER}"
