#!/usr/bin/env bash
set -euo pipefail

ARCHIVE_URL="https://github.com/elite-guy5/token-saver-setup/archive/refs/heads/main.tar.gz"
tmp_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

download_archive() {
  local archive="$1"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$ARCHIVE_URL" -o "$archive"
    return 0
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO "$archive" "$ARCHIVE_URL"
    return 0
  fi

  printf 'error: curl or wget is required to download setup archive\n' >&2
  exit 1
}

archive="$tmp_dir/token-saver-setup.tar.gz"
download_archive "$archive"
tar -xzf "$archive" -C "$tmp_dir"

repo_dir="$tmp_dir/token-saver-setup-main"
exec bash "$repo_dir/scripts/install.sh" "$@"
