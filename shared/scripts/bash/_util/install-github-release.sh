#!/usr/bin/env bash
set -euo pipefail

_UTIL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${_UTIL_DIR}/detect-platform.sh"
source "${_UTIL_DIR}/elevate.sh"
source "${_UTIL_DIR}/is-installed.sh"

for cmd in curl jq; do
  is_installed "$cmd" || {
    echo "[ERROR] missing dependency: $cmd" >&2
    exit 1
  }
done

function github_os() {
  case "$(detect_os_family)" in
  linux) echo "linux" ;;
  macos) echo "darwin" ;;
  windows) echo "windows" ;;
  *)
    echo "unknown"
    ;;
  esac
}

function github_arch() {
  detect_arch
}

function github_release_api_url() {
  local repo="$1"
  local tag="${2:-latest}"

  if [[ "$tag" == "latest" ]]; then
    echo "https://api.github.com/repos/${repo}/releases/latest"
  else
    echo "https://api.github.com/repos/${repo}/releases/tags/${tag}"
  fi
}

function github_release_json() {
  local repo="$1"
  local tag="${2:-latest}"

  curl -fsSL "$(github_release_api_url "$repo" "$tag")"
}

function github_release_assets() {
  local repo="$1"
  local tag="${2:-latest}"

  github_release_json "$repo" "$tag" |
    jq -r '.assets[] | "\(.name)\t\(.browser_download_url)"'
}

function github_asset_score() {
  local asset="$1"

  local os arch score
  os="$(github_os)"
  arch="$(github_arch)"

  score=0

  ## Strong platform matches
  [[ "$asset" =~ $os ]] && ((score += 50))
  [[ "$asset" =~ $arch ]] && ((score += 50))

  ## Alternative arch aliases
  case "$arch" in
  amd64)
    [[ "$asset" =~ x86_64|x64 ]] && ((score += 25))
    ;;
  arm64)
    [[ "$asset" =~ aarch64 ]] && ((score += 25))
    ;;
  esac

  ## Prefer archives over checksums
  [[ "$asset" =~ \.tar\.gz|\.tgz|\.zip ]] && ((score += 10))

  ## Penalize source archives
  [[ "$asset" =~ source|src|Source ]] && ((score -= 100))

  ## Penalize checksum files
  [[ "$asset" =~ sha256|checksum|\.sum ]] && ((score -= 100))

  echo "$score"
}

function github_select_asset() {
  local repo="$1"
  local tag="${2:-latest}"
  local pattern="${3:-}"

  local best_score=-999
  local best_name=""
  local best_url=""

  while IFS=$'\t' read -r name url; do
    [[ -z "$name" ]] && continue

    ## Optional user filter
    if [[ -n "$pattern" ]]; then
      echo "$name" | grep -E "$pattern" >/dev/null || continue
    fi

    local score
    score="$(github_asset_score "$name")"

    if ((score > best_score)); then
      best_score="$score"
      best_name="$name"
      best_url="$url"
    fi
  done < <(github_release_assets "$repo" "$tag")

  [[ -z "$best_url" ]] && return 1

  echo "${best_name}"$'\t'"${best_url}"
}

function github_download_asset() {
  local url="$1"
  local output="$2"

  mkdir -p "$(dirname "$output")"

  curl -fL "$url" -o "$output"
}

function github_extract_asset() {
  local archive="$1"
  local output_dir="$2"

  mkdir -p "$output_dir"

  case "$archive" in
  *.tar.gz | *.tgz)
    tar -xzf "$archive" -C "$output_dir"
    ;;
  *.zip)
    unzip -o "$archive" -d "$output_dir"
    ;;
  *)
    echo "[WARN] unsupported archive format: $archive" >&2
    return 1
    ;;
  esac
}

function install_github_binary() {
  local repo="$1"
  local binary_name="$2"
  local tag="${3:-latest}"

  local selected
  selected="$(github_select_asset "$repo" "$tag")"

  local asset_name asset_url
  asset_name="$(echo "$selected" | cut -f1)"
  asset_url="$(echo "$selected" | cut -f2)"

  [[ -z "$asset_url" ]] && {
    echo "[ERROR] failed to locate release asset" >&2
    return 1
  }

  echo "[INFO] Selected asset: $asset_name"

  local tmp_dir
  tmp_dir="$(mktemp -d)"

  trap 'rm -rf "$tmp_dir"' EXIT

  local archive
  archive="${tmp_dir}/${asset_name}"

  github_download_asset "$asset_url" "$archive"

  ## Extract if archive
  case "$archive" in
  *.tar.gz | *.tgz | *.zip)
    github_extract_asset "$archive" "$tmp_dir"
    ;;
  esac

  ## Locate binary
  local binary
  binary="$(
    find "$tmp_dir" -type f \
      -name "$binary_name" \
      -perm -u+x |
      head -n1
  )"

  ## Raw binary fallback
  [[ -z "$binary" ]] && binary="$archive"

  echo "[INFO] Installing ${binary_name}"

  run_privileged install -m 755 "$binary" "/usr/local/bin/${binary_name}"
}
