#!/usr/bin/env bash
set -euo pipefail

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${_DIR}/../_util/is-installed.sh"
source "${_DIR}/../_util/install-pkg.sh"
source "${_DIR}/../_util/detect-platform.sh"

function install_jq_binary() {
  local arch url

  arch="$(detect_arch)"

  url="https://github.com/jqlang/jq/releases/latest/download/jq-linux-${arch}"

  echo "Downloading jq binary"

  curl -L "$url" -o jq
  chmod +x jq
  sudo mv jq /usr/local/bin/jq
}

function main() {
  if is_installed jq; then
    echo "jq already installed"
    jq --version
    return 0
  fi

  if ! install_pkg jq; then
    echo "Package manager install failed; using binary fallback"
    install_jq_binary
  fi

  echo "jq installation complete"
  jq --version
}

main "$@"
