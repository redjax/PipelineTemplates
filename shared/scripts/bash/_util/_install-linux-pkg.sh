#!/usr/bin/env bash
set -euo pipefail

_UTIL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${_UTIL_DIR}/detect-platform.sh"

#
# Create ephemeral cache dir once per script execution
#
if [[ -z "${PKG_UPDATE_CACHE_DIR:-}" ]]; then
  readonly PKG_UPDATE_CACHE_DIR
  PKG_UPDATE_CACHE_DIR="$(mktemp -d)"

  cleanup_pkg_update_cache() {
    rm -rf "$PKG_UPDATE_CACHE_DIR"
  }

  trap cleanup_pkg_update_cache EXIT
fi

function _pkg_update_cache_file() {
  local pkg_manager="$1"
  echo "${PKG_UPDATE_CACHE_DIR}/${pkg_manager}"
}

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
    # no update step usually needed
    true
    ;;
  *)
    echo "Unknown package manager: $pkg_manager" >&2
    return 1
    ;;
  esac

  touch "$cache_file"
}

function run_privileged() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

function install_linux_pkg() {
  local default_pkg="$1"

  shift || true

  local pkg_manager
  pkg_manager="$(detect_pkg_manager)"

  if [[ "$pkg_manager" == "unknown" ]]; then
    echo "Unable to detect package manager" >&2
    return 1
  fi

  local resolved_pkg="$default_pkg"

  ## Optional package name overrides:
  #
  # install_linux_pkg \
  #   default-name \
  #   apt=foo \
  #   apk=bar
  for arg in "$@"; do
    if [[ "$arg" == "${pkg_manager}="* ]]; then
      resolved_pkg="${arg#*=}"
      break
    fi
  done

  ensure_pkg_manager_updated "$pkg_manager"

  echo "Installing package '$resolved_pkg' via $pkg_manager"

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
