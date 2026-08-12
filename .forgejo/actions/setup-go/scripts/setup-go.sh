#!/usr/bin/env bash
set -euo pipefail

########################################################################
# Forgejo Actions Go installer                                         #
#                                                                      #
# Installs and configures Go toolchains without requiring root.        #
########################################################################

: "${GO_VERSION:?GO_VERSION must be set}"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

case "$(uname -m)" in
x86_64)
  ARCH="amd64"
  ;;
aarch64 | arm64)
  ARCH="arm64"
  ;;
*)
  echo "Unsupported architecture: $(uname -m)"
  exit 1
  ;;
esac

CACHE_ROOT="${HOME}/.cache/setup-go"
DOWNLOAD_DIR="${CACHE_ROOT}/downloads"

TOOLCHAIN_DIR="${HOME}/.local/share/setup-go/toolchains/${GO_VERSION}"

mkdir -p \
  "${DOWNLOAD_DIR}" \
  "${TOOLCHAIN_DIR}"

TARBALL="${DOWNLOAD_DIR}/go${GO_VERSION}.${OS}-${ARCH}.tar.gz"

## Download Go archive

if [[ -f "${TARBALL}" ]]; then
  echo "Using cached Go archive:"
  echo "  ${TARBALL}"
else
  echo "Downloading Go ${GO_VERSION}"

  curl \
    --fail \
    --location \
    --retry 3 \
    --output "${TARBALL}" \
    "https://go.dev/dl/go${GO_VERSION}.${OS}-${ARCH}.tar.gz"
fi

## Install toolchain

if [[ -x "${TOOLCHAIN_DIR}/bin/go" ]]; then

  INSTALLED_VERSION="$(
    "${TOOLCHAIN_DIR}/bin/go" version |
      awk '{print $3}' |
      sed 's/^go//'
  )"

  if [[ "${INSTALLED_VERSION}" == "${GO_VERSION}" ]]; then
    echo "Using cached Go toolchain ${GO_VERSION}"
  else
    echo "Removing mismatched Go toolchain"
    rm -rf "${TOOLCHAIN_DIR}"
  fi
fi

if [[ ! -x "${TOOLCHAIN_DIR}/bin/go" ]]; then

  echo "Installing Go ${GO_VERSION}"

  rm -rf "${TOOLCHAIN_DIR}"
  mkdir -p "${TOOLCHAIN_DIR}"

  tar \
    --extract \
    --gzip \
    --file "${TARBALL}" \
    --directory "${TOOLCHAIN_DIR}" \
    --strip-components=1

fi

## Configure environment for later Forgejo steps

if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "${TOOLCHAIN_DIR}/bin" >>"${GITHUB_PATH}"
fi

if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "GOROOT=${TOOLCHAIN_DIR}" >>"${GITHUB_ENV}"
  echo "GOPATH=${HOME}/go" >>"${GITHUB_ENV}"
fi

export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"
export GOROOT="${TOOLCHAIN_DIR}"
export GOPATH="${HOME}/go"

mkdir -p \
  "${HOME}/.cache/go/build" \
  "${HOME}/.cache/go/pkg/mod"

if [[ "${ENABLE_CACHE:-true}" == "true" ]]; then
  if [[ -n "${GITHUB_ENV:-}" ]]; then
    echo "GOCACHE=${HOME}/.cache/go/build" >>"${GITHUB_ENV}"
    echo "GOMODCACHE=${HOME}/.cache/go/pkg/mod" >>"${GITHUB_ENV}"
  fi

  export GOCACHE="${HOME}/.cache/go/build"
  export GOMODCACHE="${HOME}/.cache/go/pkg/mod"

  echo "Go cache enabled"

else

  echo "Go cache disabled"

fi

## Verify

echo
echo "Go installation complete:"
echo

export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"

echo "Installed Go toolchain:"
"${TOOLCHAIN_DIR}/bin/go" version

echo
echo "Selected Go toolchain:"
go version

echo
echo "Go environment:"
go env GOROOT GOPATH GOCACHE GOMODCACHE
