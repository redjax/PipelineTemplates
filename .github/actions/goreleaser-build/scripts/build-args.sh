#!/usr/bin/env bash
set -euo pipefail

##########################################
# Build arguments for goreleaser command #
##########################################

## Inputs are passed via env
CLEAN="${CLEAN:-true}"
SNAPSHOT="${SNAPSHOT:-false}"
SKIP_VALIDATE="${SKIP_VALIDATE:-false}"
SKIP_PUBLISH="${SKIP_PUBLISH:-false}"
RELEASE_NOTES="${RELEASE_NOTES:-}"
EXTRA_ARGS="${EXTRA_ARGS:-}"

ARGS=""

## Determine command (build or release)
if [[ "$SNAPSHOT" == "true" ]] || [[ "$SKIP_PUBLISH" == "true" ]]; then
  ARGS="build"
else
  ARGS="release"
fi

## Add flags
[[ "$CLEAN" == "true" ]] && ARGS="$ARGS --clean"
[[ "$SNAPSHOT" == "true" ]] && ARGS="$ARGS --snapshot"
[[ "$SKIP_VALIDATE" == "true" ]] && ARGS="$ARGS --skip=validate"
[[ -n "$RELEASE_NOTES" ]] && ARGS="$ARGS --release-notes=$RELEASE_NOTES"
[[ -n "$EXTRA_ARGS" ]] && ARGS="$ARGS $EXTRA_ARGS"

echo "args=$ARGS" >>"$GITHUB_OUTPUT"
echo "GoReleaser will run: goreleaser $ARGS"
