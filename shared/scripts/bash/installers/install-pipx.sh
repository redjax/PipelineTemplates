#!/usr/bin/env bash
set -euo pipefail

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${_DIR}/../_util/is-installed.sh"
source "${_DIR}/../_util/install-pkg.sh"

function ensure_pip() {
  if is_installed pip3; then
    return 0
  fi

  echo "[INFO] Installing python3-pip"

  install_pkg python3-pip \
    apk=py3-pip \
    pacman=python-pip
}

function install_pipx_package() {
  echo "[INFO] Installing pipx package"

  install_pkg pipx
}

function install_pipx_pip() {
  echo "[INFO] Installing pipx via pip3"

  pip3 install --user pipx

  ## Ensure ~/.local/bin exists in PATH
  if command -v pipx >/dev/null 2>&1; then
    return 0
  fi

  local user_bin
  user_bin="${HOME}/.local/bin"

  if [[ ":$PATH:" != *":${user_bin}:"* ]]; then
    export PATH="${user_bin}:${PATH}"
  fi

  ## Attempt shell integration
  if command -v pipx >/dev/null 2>&1; then
    pipx ensurepath || true
  fi
}

function main() {
  if is_installed pipx; then
    echo "pipx already installed"
    pipx --version

    return 0
  fi

  ensure_pip

  ## Preferred install path
  if install_pipx_package; then
    echo "pipx installation complete"
    pipx --version

    return 0
  fi

  ## Fallback
  echo "[WARN] Native package install failed; using pip fallback"

  install_pipx_pip

  if ! command -v pipx >/dev/null 2>&1; then
    echo "[ERROR] pipx installation failed" >&2
    return 1
  fi

  echo "pipx installation complete"
  pipx --version
}

main "$@"
