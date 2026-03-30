#!/usr/bin/env bash
set -euo pipefail

function usage() {
  echo ""
  echo "Usage: ${0} [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --template  <string>  The name of the template whose version will be bumped."
  echo "  --version   <string>  The version to bump to, i.e. v0.0.1, v0.1.0, etc."
  echo "  --tag       <bool>    When present, create a git tag."
  echo ""
  echo "Environment variables:"
  echo "  TEMPLATE              Same as --template"
  echo "  VERSION               Same as --version"
  echo "  DO_TAG                Set to 1 to create a git tag"
  echo ""
  echo "Examples:"
  echo "  $(basename "$0") --template github/demo-hello --version v0.0.1"
  echo "  $(basename "$0") --template github/demo-hello --version v0.0.1 --tag"
  echo "  TEMPLATE=github/demo-hello VERSION=v0.0.1 DO_TAG=1 $(basename "$0")"
  echo ""
}

TEMPLATE="${TEMPLATE:-}"
VERSION="${VERSION:-}"
DO_TAG="${DO_TAG:-0}"

## Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --template)
      TEMPLATE="${2:?missing value for --template}"
      shift 2
      ;;
    --version)
      VERSION="${2:?missing value for --version}"
      shift 2
      ;;
    --tag)
      DO_TAG=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$TEMPLATE" || -z "$VERSION" ]]; then
  echo "[ERROR] --template and --version are required (or set TEMPLATE and VERSION)" >&2
  usage >&2
  exit 1
fi

MANIFEST="manifests/versions.yml"
TAG="${TEMPLATE}/${VERSION}"

## Create git tag if --tag was passed
if [[ "$DO_TAG" -eq 1 ]] && git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
  echo "[ERROR] Tag already exists: ${TAG}" >&2
  exit 1
fi

## Create workin dir
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

## Find and bump template version
awk -v key="$TEMPLATE" -v val="$VERSION" '
BEGIN { found = 0 }
$1 == key ":" {
  print key ": " val
  found = 1
  next
}
{ print }
END {
  if (!found) print key ": " val
}
' "$MANIFEST" > "$tmp"

## Overwrite manifest
mv "$tmp" "$MANIFEST"


## Add updated manifest
git add "$MANIFEST"
git commit -m "Release ${TEMPLATE} ${VERSION}"


## If --tag was passed, create a git tag
if [[ "$DO_TAG" -eq 1 ]]; then
  git tag -a "$TAG" -m "${TEMPLATE} ${VERSION}"
fi
