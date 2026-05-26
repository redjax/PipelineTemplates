#!/usr/bin/env bash
set -Eeuo pipefail

##################################################################
# Commits changes and deploys to a branch.                       #
#                                                                #
# Environment variables:                                         #
#   HUGO_SOURCE_DIR       (default .)                            #
#   HUGO_BUILD_FLAGS      (default "--gc --minify")              #
#   HUGO_PUBLIC_DIR       (default "public")                     #
#   HUGO_DEPLOY_BRANCH    (default "deploy")                     #
#   HUGO_COMMIT_MESSAGE   (default "Deploy from GitHub Actions") #
#   GIT_USER_NAME         (default "GitHub Action")              #
#   GIT_USER_EMAIL        (default "action@github.com")          #
##################################################################

SOURCE_DIR="${HUGO_SOURCE_DIR:-.}"
BUILD_FLAGS="${HUGO_BUILD_FLAGS:---gc --minify}"
PUBLIC_DIR="${HUGO_PUBLIC_DIR:-public}"
DEPLOY_BRANCH="${HUGO_DEPLOY_BRANCH:-deploy}"
COMMIT_MESSAGE="${HUGO_COMMIT_MESSAGE:-Deploy from GitHub Actions}"
GIT_USER_NAME="${GIT_USER_NAME:-GitHub Action}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-action@github.com}"

cd "$SOURCE_DIR"

git config user.name "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"

echo "[INFO] Checking out deploy branch: $DEPLOY_BRANCH"
git checkout -B "$DEPLOY_BRANCH"

echo "[INFO] Rebuilding site on deploy branch..."
hugo $BUILD_FLAGS

git add -f "${PUBLIC_DIR}/"
git add .

if git diff --cached --quiet; then
  echo "[INFO] No changes to commit; skipping push."
  exit 0
fi

git commit -m "$COMMIT_MESSAGE"
git push origin "$DEPLOY_BRANCH" --force

echo "[INFO] Deployed to branch: $DEPLOY_BRANCH"
