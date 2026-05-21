#!/usr/bin/env bash
set -uo pipefail

#################################################
# Provides functions that detect platform info, #
# such as OS, release, CPU architecture, etc    #
#################################################

## Detect OS (linux, darwin, etc)
function detect_os() {
  uname -s | tr '[:upper:]' '[:lower:]'
}

function detect_release_id() {
  [[ -f /etc/os-release ]] && source /etc/os-release && echo "${ID:-unknown}"
}

function detect_release_version() {
  [[ -f /etc/os-release ]] && source /etc/os-release && echo "${VERSION_ID:-unknown}"
}

function detect_release() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release

    local id="${ID:-unknown}"
    local version="${VERSION_ID:-unknown}"

    ## Fedora sometimes includes VERSION like "42 (Workstation Edition)"
    #  VERSION_ID is already clean ("42")

    echo "${id} ${version}"
    return 0
  fi

  echo "unknown unknown"
}

function detect_kernel_version() {
  uname -r
}

## Detect architecture (amd64, arm64, etc)
function detect_arch() {
  local arch
  arch=$(uname -m)

  case "$arch" in
  x86_64) echo "amd64" ;;
  amd64) echo "amd64" ;;
  arm64 | aarch64) echo "arm64" ;;
  armv7l) echo "armv7" ;;
  *) echo "$arch" ;;
  esac
}

## Detect package manager
function detect_pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  elif command -v apk >/dev/null 2>&1; then
    echo "apk"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v brew >/dev/null 2>&1; then
    echo "brew"
  else
    echo "unknown"
  fi
}

## OS family grouping
function detect_os_family() {
  case "$(detect_os)" in
  linux) echo "linux" ;;
  darwin) echo "macos" ;;
  msys* | cygwin* | mingw*) echo "windows" ;;
  *) echo "unknown" ;;
  esac
}

function debug_platform() {
  local os id version arch kernel

  os="$(detect_os_family)"
  arch="$(detect_arch)"
  kernel="$(detect_kernel_version)"

  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    id="${ID:-unknown}"
    version="${VERSION_ID:-unknown}"
  else
    id="unknown"
    version="unknown"
  fi

  echo "os=${os} distro=${id} version=${version} arch=${arch} kernel=${kernel}"
}

## If executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  debug_platform
fi
