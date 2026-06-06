#!/usr/bin/env bash
set -euo pipefail

PINNED_COMMIT="49253c77fb7b32786c6d63e89d38ea763310a25a"
ARCHIVE_URL="https://github.com/elite-guy5/token-saver-setup/archive/$PINNED_COMMIT.tar.gz"
ARCHIVE_SHA256="38c13a13a117c5e04becffcf9400ba14a75221f3ec4a8db04fa9d99da4f9cbb8"
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

verify_archive() {
  local archive="$1"
  local actual=""

  if command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$archive" | awk '{print $1}')"
  elif command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$archive" | awk '{print $1}')"
  else
    printf 'error: shasum or sha256sum is required to verify setup archive checksum\n' >&2
    exit 1
  fi

  if [ "$actual" != "$ARCHIVE_SHA256" ]; then
    printf 'error: setup archive checksum mismatch\n' >&2
    printf 'expected: %s\n' "$ARCHIVE_SHA256" >&2
    printf 'actual:   %s\n' "$actual" >&2
    exit 1
  fi
}

archive="$tmp_dir/token-saver-setup.tar.gz"
download_archive "$archive"
verify_archive "$archive"
tar -xzf "$archive" -C "$tmp_dir"

repo_dir="$tmp_dir/token-saver-setup-$PINNED_COMMIT"
exec bash "$repo_dir/scripts/install.sh" "$@"
