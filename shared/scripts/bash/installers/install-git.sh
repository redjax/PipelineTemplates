#!/usr/bin/env bash
set -euo pipefail

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${_DIR}/../_util/is-installed.sh"
source "${_DIR}/../_util/install-pkg.sh"

function main() {
  if is_installed git; then
    echo "git already installed"
    git --version
    return 0
  fi

  install_pkg git

  echo "git installation complete"
  git --version
}

main "$@"
