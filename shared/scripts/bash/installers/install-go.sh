#!/usr/bin/env bash
set -euo pipefail

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${_DIR}/../_util/is-installed.sh"
source "${_DIR}/../_util/detect-platform.sh"
source "${_DIR}/../_util/elevate.sh"

##########################################################################
# Install Go                                                             #
#                                                                        #
# Installs the latest version of Go, or a pinned version from a string.  #
#                                                                        #
# Usage:                                                                 #
#   install-go.sh                                                        #
#   install-go.sh 1.26.3                                                 #
#   install-go.sh go1.26.3                                               #
##########################################################################

VERSION="${1:-latest}"

## Normalize version string
function normalize_version() {
  local version="$1"

  if [[ "$version" == "latest" ]]; then
    echo "latest"
    return 0
  fi

  ## Ensure leading "go"
  if [[ "$version" != go* ]]; then
    version="go${version}"
  fi

  echo "$version"
}

## Detect platform
function go_os() {
  case "$(detect_os_family)" in
  linux)
    echo "linux"
    ;;
  macos)
    echo "darwin"
    ;;
  *)
    echo "unsupported"
    ;;
  esac
}

function go_arch() {
  case "$(detect_arch)" in
  amd64)
    echo "amd64"
    ;;
  arm64)
    echo "arm64"
    ;;
  *)
    echo "unsupported"
    ;;
  esac
}

## Resolve latest version
function resolve_latest_version() {
  curl -fsSL https://go.dev/VERSION?m=text | head -n1
}

## Append to PATH for current shell & CI pipelines
function ensure_go_path() {
  export PATH="/usr/local/go/bin:${PATH}"

  ## GitHub Actions
  if [[ -n "${GITHUB_PATH:-}" ]]; then
    echo "/usr/local/go/bin" >>"${GITHUB_PATH}"
  fi
}

function install_go() {
  local version="$1"

  local os arch filename url tmp_dir archive

  os="$(go_os)"
  arch="$(go_arch)"

  if [[ "$os" == "unsupported" ]]; then
    echo "[ERROR] unsupported OS" >&2
    return 1
  fi

  if [[ "$arch" == "unsupported" ]]; then
    echo "[ERROR] unsupported architecture" >&2
    return 1
  fi

  if [[ "$version" == "latest" ]]; then
    version="$(resolve_latest_version)"
  else
    version="$(normalize_version "$version")"
  fi

  filename="${version}.${os}-${arch}.tar.gz"
  url="https://go.dev/dl/${filename}"

  echo "[INFO] Installing Go ${version}"
  echo "[INFO] Download URL: ${url}"

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  archive="${tmp_dir}/${filename}"

  curl -fL "$url" -o "$archive"

  echo "[INFO] Removing existing Go installation"
  run_privileged rm -rf /usr/local/go

  echo "[INFO] Extracting Go"
  run_privileged tar -C /usr/local -xzf "$archive"

  ensure_go_path

  echo "[INFO] Go installation complete"
  go version
}

function main() {
  local requested_version resolved_version

  requested_version="$(normalize_version "$VERSION")"

  if [[ "$requested_version" == "latest" ]]; then
    resolved_version="$(resolve_latest_version)"
  else
    resolved_version="$requested_version"
  fi

  if is_installed go; then
    local installed_version

    installed_version="$(go version | awk '{print $3}')"

    if [[ "$installed_version" == "$resolved_version" ]]; then
      echo "Go ${resolved_version} already installed"
      go version
      return 0
    fi

    echo "[INFO] Different Go version installed:"
    echo "  installed: ${installed_version}"
    echo "  requested: ${resolved_version}"
  fi

  install_go "$requested_version"
}

main "$@"
