#!/usr/bin/env bash
set -euo pipefail

################################################
# Display build summary after GoReleaser build #
################################################

GORELEASER_CONFIG="${GORELEASER_CONFIG:-.goreleaser.yml}"
SNAPSHOT="${SNAPSHOT:-false}"
GO_VERSION="${GO_VERSION:-unknown}"
GORELEASER_VERSION="${GORELEASER_VERSION:-latest}"

{
  echo "## GoReleaser Build Summary"
  echo
  echo "- **Config**: \`$GORELEASER_CONFIG\`"
  echo "- **Snapshot**: $SNAPSHOT"
  echo "- **Go Version**: $GO_VERSION"
  echo "- **GoReleaser Version**: $GORELEASER_VERSION"

  if [[ -d dist ]]; then
    echo
    echo "### Artifacts Generated"
    echo '```'
    find dist -type f | head -20
    echo '```'
  fi
} >>"$GITHUB_STEP_SUMMARY"
