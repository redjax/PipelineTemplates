#!/usr/bin/env bash
set -euo pipefail

_UTIL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${_UTIL_DIR}/detect-platform.sh"
source "${_UTIL_DIR}/elevate.sh"

## Create ephemeral cache dir once per script execution
if [[ -z "${PKG_UPDATE_CACHE_DIR:-}" ]]; then
  PKG_UPDATE_CACHE_DIR="$(mktemp -d)"
  readonly PKG_UPDATE_CACHE_DIR

  cleanup_pkg_update_cache() {
    rm -rf "$PKG_UPDATE_CACHE_DIR"
  }

  trap cleanup_pkg_update_cache EXIT
fi

## Create file indicating a package manager has recently run its update command
function _pkg_update_cache_file() {
  local pkg_manager="$1"
  echo "${PKG_UPDATE_CACHE_DIR}/${pkg_manager}"
}

## Do package manager update, then write a file to
#  prevent re-running updates in the same script/pipeline.
function ensure_pkg_manager_updated() {
  local pkg_manager="$1"

  local cache_file
  cache_file="$(_pkg_update_cache_file "$pkg_manager")"

  if [[ -f "$cache_file" ]]; then
    echo "Package manager already updated: $pkg_manager"
    return 0
  fi

  echo "Updating package manager: $pkg_manager"

  case "$pkg_manager" in
  apt)
    run_privileged apt-get update -y
    ;;
  apk)
    run_privileged apk update
    ;;
  pacman)
    run_privileged pacman -Sy --noconfirm
    ;;
  dnf | yum)
    true
    ;;
  *)
    echo "Unknown package manager: $pkg_manager" >&2
    return 1
    ;;
  esac

  touch "$cache_file"
}

## Detect the package name to use according to package manager
function resolve_pkg_name() {
  local default_pkg="$1"
  local target="$2"

  shift 2 || true

  local resolved_pkg="$default_pkg"

  for arg in "$@"; do
    if [[ "$arg" == "${target}="* ]]; then
      resolved_pkg="${arg#*=}"
      break
    fi
  done

  echo "$resolved_pkg"
}

## Install a package on a Linux distribution.
#  Note: Not all package managers are supported.
function _install_linux_pkg() {
  local default_pkg="$1"

  shift || true

  local pkg_manager
  pkg_manager="$(detect_pkg_manager)"

  if [[ "$pkg_manager" == "unknown" ]]; then
    echo "Unable to detect package manager" >&2
    return 1
  fi

  local resolved_pkg
  resolved_pkg="$(resolve_pkg_name "$default_pkg" "$pkg_manager" "$@")"

  ensure_pkg_manager_updated "$pkg_manager"

  echo "Installing '$resolved_pkg' via $pkg_manager"

  case "$pkg_manager" in
  apt)
    run_privileged apt-get install -y "$resolved_pkg"
    ;;
  dnf)
    run_privileged dnf install -y "$resolved_pkg"
    ;;
  yum)
    run_privileged yum install -y "$resolved_pkg"
    ;;
  apk)
    run_privileged apk add "$resolved_pkg"
    ;;
  pacman)
    run_privileged pacman -S --noconfirm "$resolved_pkg"
    ;;
  *)
    echo "Unsupported package manager: $pkg_manager" >&2
    return 1
    ;;
  esac
}

## Install a package on macOS
function _install_macos_pkg() {
  local default_pkg="$1"

  shift || true

  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found" >&2
    return 1
  fi

  local resolved_pkg
  resolved_pkg="$(resolve_pkg_name "$default_pkg" "brew" "$@")"

  echo "Installing '$resolved_pkg' via brew"

  brew install "$resolved_pkg"
}

## Usage:
#
#    Install a single package:
#      install_pkg curl
#
#  Install a package whose name differs across distros:
#    install_pkg python3-pip \
#      apk=py3-pip \
#      pacman=python-pip
#
#   Install a package on macOS using Homebrew:
#     install_pkg nodejs \
#     brew=node
function install_pkg() {
  local pkg="$1"

  shift || true

  local os
  os="$(detect_os_family)"

  case "$os" in
  linux)
    install_linux_pkg "$pkg" "$@"
    ;;
  macos)
    install_macos_pkg "$pkg" "$@"
    ;;
  *)
    echo "Unsupported OS: $os" >&2
    return 1
    ;;
  esac
}
