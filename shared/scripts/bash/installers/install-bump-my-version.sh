#!/usr/bin/env bash
set -euo pipefail

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${_DIR}/../_util/is-installed.sh"
source "${_DIR}/../_util/install-pkg.sh"
source "${_DIR}/../_util/install-github-release.sh"

#########################################################
# Install bump-my-version                               #
#                                                       #
# Installs:                                             #
#   https://github.com/callowayproject/bump-my-version  #
#                                                       #
# Strategy:                                             #
#   1. Use pip/pipx if available                        #
#   2. Fallback to GitHub release binary install        #
#########################################################

function install_bump_my_version_pip() {
  ## Prefer pipx if available
  if is_installed pipx; then
    echo "[INFO] Installing bump-my-version via pipx"
    pipx install bump-my-version
    return 0
  fi

  ## Fall back to pip
  if is_installed pip3; then
    echo "[INFO] Installing bump-my-version via pip3"
    pip3 install --user bump-my-version

    ## Add .local/bin to path in Github pipelines
    if [[ -n "${GITHUB_PATH:-}" ]]; then
      echo "$HOME/.local/bin" >>"$GITHUB_PATH"
    fi

    return 0
  fi

  return 1
}

function ensure_python_tools() {
  ## pipx preferred
  if is_installed pipx; then
    return 0
  fi

  ## Install pip3 if missing
  if ! is_installed pip3; then
    echo "[INFO] Installing python pip"

    install_pkg python3-pip \
      apk=py3-pip \
      pacman=python-pip
  fi

  ## Attempt pipx install
  if ! is_installed pipx; then
    echo "[INFO] Installing pipx"

    install_pkg pipx || true

    ## Fallback if distro lacks pipx package
    if ! is_installed pipx && is_installed pip3; then
      pip3 install --user pipx
    fi
  fi
}

function main() {
  if is_installed bump-my-version; then
    echo "bump-my-version already installed"
    bump-my-version --version

    return 0
  fi

  ensure_python_tools

  ## Preferred install path
  if install_bump_my_version_pip; then
    echo "bump-my-version installation complete"
    bump-my-version --version
    return 0
  fi

  echo "[WARN] pip installation failed; trying GitHub release"

  ## GitHub release installer
  install_github_binary \
    callowayproject/bump-my-version \
    bump-my-version

  echo "bump-my-version installation complete"
  bump-my-version --version
}

main "$@"
