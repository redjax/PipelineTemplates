#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

##############################################
# GoReleaser Build Script                   #
#                                           #
# Flexible script to run GoReleaser with   #
# various options and configurations.       #
##############################################

## Configuration from environment variables
goreleaser_config="${GORELEASER_CONFIG:-.goreleaser.yml}"
snapshot="${SNAPSHOT:-false}"
clean="${CLEAN:-true}"
skip_validate="${SKIP_VALIDATE:-false}"
skip_publish="${SKIP_PUBLISH:-false}"
goreleaser_version="${GORELEASER_VERSION:-latest}"
docker_build="${DOCKER_BUILD:-false}"
extra_args="${EXTRA_ARGS:-}"
dry_run="${DRY_RUN:-false}"
release_notes="${RELEASE_NOTES:-}"
github_token="${GITHUB_TOKEN:-}"

function log_info() {
  echo "[INFO] $*" >&2
}

function log_error() {
  echo "[ERROR] $*" >&2
}

function log_verbose() {
  echo "[VERBOSE] $*" >&2
}

## Display configuration
log_info "=========================================="
log_info "  GoReleaser Build Configuration"
log_info "=========================================="
log_info "Config file:       $goreleaser_config"
log_info "Snapshot:          $snapshot"
log_info "Clean:             $clean"
log_info "Skip validate:     $skip_validate"
log_info "Skip publish:      $skip_publish"
log_info "GoReleaser version: $goreleaser_version"
log_info "Docker build:      $docker_build"
log_info "Dry run:           $dry_run"
[[ -n "$release_notes" ]] && log_info "Release notes:     $release_notes"
[[ -n "$extra_args" ]] && log_info "Extra args:        $extra_args"
log_info "=========================================="
echo ""

## Validate configuration file exists
if [[ ! -f "$goreleaser_config" ]]; then
  log_error "GoReleaser config not found: $goreleaser_config"
  log_info "Please create a .goreleaser.yml file in your repository"
  log_info "See: https://goreleaser.com/customization/"
  exit 1
fi

log_info "Found GoReleaser config: $goreleaser_config"

## Install GoReleaser
log_info "Installing GoReleaser $goreleaser_version"

# Create bin directory
GORELEASER_DIR="${HOME}/.local/bin"
mkdir -p "$GORELEASER_DIR"

if [[ "$goreleaser_version" == "latest" ]]; then
  # Install latest version
  GORELEASER_URL="https://github.com/goreleaser/goreleaser/releases/latest/download/goreleaser_Linux_x86_64.tar.gz"
  log_verbose "Downloading from: $GORELEASER_URL"
  curl -sfL "$GORELEASER_URL" -o /tmp/goreleaser.tar.gz
  tar -xzf /tmp/goreleaser.tar.gz -C /tmp
  mv /tmp/goreleaser "$GORELEASER_DIR/goreleaser"
  chmod +x "$GORELEASER_DIR/goreleaser"
  rm -f /tmp/goreleaser.tar.gz
else
  # Install specific version
  GORELEASER_URL="https://github.com/goreleaser/goreleaser/releases/download/v${goreleaser_version}/goreleaser_Linux_x86_64.tar.gz"
  log_verbose "Downloading from: $GORELEASER_URL"
  curl -sfL "$GORELEASER_URL" -o /tmp/goreleaser.tar.gz
  tar -xzf /tmp/goreleaser.tar.gz -C /tmp
  mv /tmp/goreleaser "$GORELEASER_DIR/goreleaser"
  chmod +x "$GORELEASER_DIR/goreleaser"
  rm -f /tmp/goreleaser.tar.gz
fi

# Add to PATH
export PATH="$GORELEASER_DIR:$PATH"
log_verbose "Added $GORELEASER_DIR to PATH"
fi

## Verify installation
if ! command -v goreleaser >/dev/null 2>&1; then
  log_error "GoReleaser installation failed"
  exit 1
fi

goreleaser_actual_version="$(goreleaser --version | head -n1)"
log_info "Installed: $goreleaser_actual_version"
echo ""

## Handle dry-run mode
if [[ "$dry_run" == "true" ]]; then
  log_info "DRY RUN MODE: Validating configuration only"
  goreleaser check -f "$goreleaser_config"
  log_info "Configuration is valid!"
  exit 0
fi

## Build GoReleaser command
declare -a goreleaser_args=()

## Determine release or build command
if [[ "$snapshot" == "true" ]] || [[ "$skip_publish" == "true" ]]; then
  goreleaser_args+=("build")
  log_info "Running in BUILD mode (no release)"
else
  goreleaser_args+=("release")
  log_info "Running in RELEASE mode"
fi

## Add config file
goreleaser_args+=("-f" "$goreleaser_config")

## Add snapshot flag
if [[ "$snapshot" == "true" ]]; then
  goreleaser_args+=("--snapshot")
  log_info "  - Snapshot mode enabled"
fi

## Add clean flag
if [[ "$clean" == "true" ]]; then
  goreleaser_args+=("--clean")
  log_info "  - Clean mode enabled"
fi

## Add skip-validate flag
if [[ "$skip_validate" == "true" ]]; then
  goreleaser_args+=("--skip=validate")
  log_info "  - Skipping validation"
fi

## Add custom release notes
if [[ -n "$release_notes" ]] && [[ -f "$release_notes" ]]; then
  goreleaser_args+=("--release-notes" "$release_notes")
  log_info "  - Using custom release notes: $release_notes"
fi

## Add extra arguments
if [[ -n "$extra_args" ]]; then
  # Split extra_args on spaces and add to array
  read -ra extra_args_array <<< "$extra_args"
  goreleaser_args+=("${extra_args_array[@]}")
  log_info "  - Extra args: $extra_args"
fi

echo ""
log_info "Executing GoReleaser"
log_verbose "Command: goreleaser ${goreleaser_args[*]}"
echo ""

## Execute GoReleaser
set +e
goreleaser "${goreleaser_args[@]}"
exit_code=$?
set -e

echo ""
if [[ $exit_code -eq 0 ]]; then
  log_info "=========================================="
  log_info "  GoReleaser completed successfully!"
  log_info "=========================================="
  
  ## Display artifacts summary
  if [[ -d dist ]]; then
    echo ""
    log_info "Generated artifacts:"
    find dist -type f -name "*.tar.gz" -o -name "*.zip" -o -name "*.deb" -o -name "*.rpm" | while read -r file; do
      size="$(du -h "$file" | cut -f1)"
      echo "  - $(basename "$file") ($size)"
    done
  fi
else
  log_error "=========================================="
  log_error "  GoReleaser failed with exit code: $exit_code"
  log_error "=========================================="
  exit $exit_code
fi

exit 0
