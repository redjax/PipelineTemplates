#!/usr/bin/env bash
set -euo pipefail

for cmd in gh jq; do
  if ! command -v "${cmd}" >&/dev/null; then
    echo "[ERROR] ${cmd} is not installed" >&2
    exit 1
  fi
done

function usage() {
  cat <<EOF
Usage:

  ${0} [OPTIONS]

Options:
  -h, --help                Show this help menu.
  --keep-latest <INT>       Keep only the latest N releases.
  --older-than <STR>        Keep only releases newer than given date (YYYY-MM-DD).
  --tag-pattern <REGEX>     Only consider tags matching this regex (e.g. ^v[0-9]+).
  --dry-run                 Show what would be deleted without deleting anything.
  --repo <OWNER/REPO>       Target a specific repo (default: current repo).

Examples:

  rm-old-github-tags.sh --keep-latest 10
  rm-old-github-tags.sh --keep-latest 10 --dry-run

  rm-old-github-tags.sh --older-than 2025-01-01
  rm-old-github-tags.sh --older-than 2025-01-01 --dry-run

  rm-old-github-tags.sh --keep-latest 5 --tag-pattern '^v[0-9]+\\.[0-9]+\\.[0-9]+$'

Requirements:

  * gh CLI
  * jq
  * authenticated GitHub session
EOF
}

KEEP_LATEST=""
OLDER_THAN=""
TAG_PATTERN=""
DRY_RUN=false
REPO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --keep-latest)
    KEEP_LATEST="$2"
    shift 2
    ;;
  --older-than)
    OLDER_THAN="$2"
    shift 2
    ;;
  --tag-pattern)
    TAG_PATTERN="$2"
    shift 2
    ;;
  --dry-run)
    DRY_RUN=true
    shift
    ;;
  --repo)
    REPO="$2"
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "ERROR: Unknown option: $1"
    usage
    exit 1
    ;;
  esac
done

if [[ -n "$KEEP_LATEST" && -n "$OLDER_THAN" ]]; then
  echo "ERROR: --keep-latest and --older-than are mutually exclusive"
  exit 1
fi

if [[ -z "$KEEP_LATEST" && -z "$OLDER_THAN" ]]; then
  echo "ERROR: one cleanup mode must be specified (--keep-latest or --older-than)"
  usage
  exit 1
fi

function delete_release() {
  local tag="$1"

  if $DRY_RUN; then
    echo "[DRY RUN] Would delete release and tag: $tag"
    return
  fi

  echo "Deleting release: $tag"
  if [[ -n "$REPO" ]]; then
    gh release delete "$tag" --yes --repo "$REPO"
  else
    gh release delete "$tag" --yes
  fi

  echo "Deleting tag: $tag"
  if [[ -n "$REPO" ]]; then
    git push "https://x-access-token:${GH_TOKEN}@github.com/${REPO}.git" ":refs/tags/$tag"
  else
    git push origin ":refs/tags/$tag"
  fi
}

## Build gh repo arg if --repo is used
GH_REPO_ARG=""
if [[ -n "$REPO" ]]; then
  GH_REPO_ARG="--repo $REPO"
fi

## Build jq filter for tag pattern
if [[ -n "$TAG_PATTERN" ]]; then
  TAG_FILTER=".[] | select(.tagName | test(\"$TAG_PATTERN\")) | .tagName"
else
  TAG_FILTER=".[].tagName"
fi

mapfile -t TAGS < <(
  gh release list $GH_REPO_ARG \
    --limit 1000 \
    --json tagName \
    --jq "$TAG_FILTER"
)

if [[ ${#TAGS[@]} -eq 0 ]]; then
  echo "No releases found."
  exit 0
fi

COUNT="${#TAGS[@]}"

## Mode: keep-latest
if [[ -n "$KEEP_LATEST" ]]; then
  if ((COUNT <= KEEP_LATEST)); then
    echo "Nothing to delete: only $COUNT release(s) found, keeping $KEEP_LATEST."
    exit 0
  fi

  for ((i = KEEP_LATEST; i < COUNT; i++)); do
    delete_release "${TAGS[$i]}"
  done
fi

## Mode: older-than
if [[ -n "$OLDER_THAN" ]]; then
  CUTOFF=$(date -u -d "$OLDER_THAN" +%s)

  ## Re-fetch with createdAt for filtering
  if [[ -n "$TAG_PATTERN" ]]; then
    CREATION_FILTER=".[] | select(.tagName | test(\"$TAG_PATTERN\")) | \"\(.tagName)|\(.createdAt)\""
  else
    CREATION_FILTER=".[] | \"\(.tagName)|\(.createdAt)\""
  fi

  gh release list $GH_REPO_ARG \
    --limit 1000 \
    --json tagName,createdAt |
    jq -r "$CREATION_FILTER" |
    while IFS="|" read -r TAG CREATED; do
      CREATED_TS=$(date -d "$CREATED" +%s)

      if ((CREATED_TS < CUTOFF)); then
        delete_release "$TAG"
      fi
    done
fi
