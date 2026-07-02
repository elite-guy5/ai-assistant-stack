#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP_REF="${TOKEN_SAVER_BOOTSTRAP_REF:-${TOKEN_SAVER_BOOTSTRAP_COMMIT:-main}}"
ARCHIVE_URL="${TOKEN_SAVER_BOOTSTRAP_URL:-https://github.com/elite-guy5/token-saver-setup/archive/$BOOTSTRAP_REF.tar.gz}"
ARCHIVE_SHA256="${TOKEN_SAVER_BOOTSTRAP_SHA256:-}"
LOCAL_ARCHIVE="${TOKEN_SAVER_BOOTSTRAP_ARCHIVE:-}"
tmp_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

download_archive() {
  local archive="$1"

  if [ -n "$LOCAL_ARCHIVE" ]; then
    cp "$LOCAL_ARCHIVE" "$archive"
    return 0
  fi

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

  [ -n "$ARCHIVE_SHA256" ] || return 0

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

extract_archive() {
  local archive="$1"
  local candidate=""
  local repo_dir=""
  local repo_count=0

  tar -xzf "$archive" -C "$tmp_dir"

  for candidate in "$tmp_dir"/token-saver-setup-*; do
    [ -d "$candidate" ] || continue
    repo_dir="$candidate"
    repo_count=$((repo_count + 1))
  done

  if [ "$repo_count" -ne 1 ]; then
    printf 'error: setup archive did not extract to one token-saver-setup directory\n' >&2
    exit 1
  fi

  printf '%s\n' "$repo_dir"
}

archive="$tmp_dir/token-saver-setup.tar.gz"
download_archive "$archive"
verify_archive "$archive"

if [ "${1:-}" = "--dry-run" ] && [ -n "$LOCAL_ARCHIVE" ]; then
  printf 'dry-run: verified local bootstrap archive\n'
  exit 0
fi

repo_dir="$(extract_archive "$archive")"
exec bash "$repo_dir/scripts/install.sh" "$@"
