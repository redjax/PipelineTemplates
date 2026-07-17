#!/usr/bin/env bash
set -euo pipefail

version="${HUGO_VERSION#v}"
## Build the filename prefix
if [[ "${HUGO_EXTENDED}" == "true" ]]; then
  file_prefix="hugo_extended"
else
  file_prefix="hugo"
fi

arch="$(uname -m)"
case "$arch" in
x86_64)
  arch="64bit"
  ;;
aarch64)
  arch="ARM64"
  ;;
*)
  echo "Unsupported arch: $arch"
  exit 1
  ;;
esac

url="https://github.com/gohugoio/hugo/releases/download/v${version}/${file_prefix}_${version}_Linux-${arch}.tar.gz"

tmpdir="$(mktemp -d)"

echo "Downloading ${file_prefix}_${version}_Linux-${arch}.tar.gz to ${tmpdir}"
curl -fsSL "$url" -o "${tmpdir}/hugo.tar.gz"

echo "Extracting hugo.tar.gz"
tar -xzf "${tmpdir}/hugo.tar.gz" -C "${tmpdir}" hugo

echo "Installing Hugo to /usr/local/bin/hugo"
chmod +x "${tmpdir}/hugo"
sudo mv "${tmpdir}/hugo" /usr/local/bin/hugo

rm -rf "${tmpdir}"

hugo version
