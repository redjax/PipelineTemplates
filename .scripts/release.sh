#!/usr/bin/env bash
set -euo pipefail

TEMPLATE="${1:?template key required}"
VERSION="${2:?version required}"
MANIFEST="manifests/versions.yml"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

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

mv "$tmp" "$MANIFEST"

git add "$MANIFEST"
git commit -m "Release ${TEMPLATE} ${VERSION}"
git tag -a "${TEMPLATE}/${VERSION}" -m "${TEMPLATE} ${VERSION}"