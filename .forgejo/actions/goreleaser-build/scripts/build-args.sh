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

## Snapshots only need to prove that the build works, so they use the faster
#  `build` command. Everything else runs the full release pipeline (binaries,
#  archives, checksums); skip-publish stops it before anything is uploaded.
if [[ "$SNAPSHOT" == "true" ]]; then
  ARGS="build"
else
  ARGS="release"
fi

if [[ "$CLEAN" == "true" ]]; then
  ARGS="$ARGS --clean"
fi

if [[ "$SNAPSHOT" == "true" ]]; then
  ARGS="$ARGS --snapshot"
fi

if [[ "$SKIP_VALIDATE" == "true" ]]; then
  ARGS="$ARGS --skip=validate"
fi

## These only exist on the `release` command.
if [[ "$SNAPSHOT" != "true" ]]; then
  if [[ "$SKIP_PUBLISH" == "true" ]]; then
    ARGS="$ARGS --skip=publish"
  fi

  if [[ -n "$RELEASE_NOTES" ]]; then
    ARGS="$ARGS --release-notes=$RELEASE_NOTES"
  fi
fi

if [[ -n "$EXTRA_ARGS" ]]; then
  ARGS="$ARGS $EXTRA_ARGS"
fi

OUTPUT="${GITHUB_OUTPUT:-${FORGEJO_OUTPUT}}"

echo "args=$ARGS" >>"$OUTPUT"
echo "GoReleaser will run: goreleaser $ARGS"
