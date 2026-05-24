#!/usr/bin/env bash
set -euo pipefail

function fetch_git_tags() {
  git fetch --tags --force
}

function tag_exists_local() {
  git rev-parse -q --verify "refs/tags/$1" >/dev/null 2>&1
}

function tag_exists_remote() {
  git ls-remote --tags origin "refs/tags/$1" | grep -q "$1" >/dev/null 2>&1
}

function tag_exists() {
  local tag="$1"
  tag_exists_local "$tag" || tag_exists_remote "$tag"
}
