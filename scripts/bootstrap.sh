#!/usr/bin/env bash
set -euo pipefail

# Resolve the archive source and optional integrity inputs from environment
# overrides so local tests and pinned remote installs can share this entry point.
BOOTSTRAP_REF="${TOKEN_SAVER_BOOTSTRAP_REF:-${TOKEN_SAVER_BOOTSTRAP_COMMIT:-main}}"
ARCHIVE_URL="${TOKEN_SAVER_BOOTSTRAP_URL:-https://github.com/elite-guy5/ai-assistant-stack/archive/$BOOTSTRAP_REF.tar.gz}"
ARCHIVE_SHA256="${TOKEN_SAVER_BOOTSTRAP_SHA256:-}"
LOCAL_ARCHIVE="${TOKEN_SAVER_BOOTSTRAP_ARCHIVE:-}"
PROMPT_TTY="${TOKEN_SAVER_PROMPT_TTY:-0}"
tmp_dir="$(mktemp -d)"

# Detect stdin-script execution so downstream prompts can read from /dev/tty
# after the piped bootstrap script has consumed stdin.
if [ -z "${BASH_SOURCE[0]:-}" ] && [ ! -t 0 ] && [ -r /dev/tty ] && [ -w /dev/tty ]; then
  PROMPT_TTY=1
fi

# Remove the temporary archive extraction directory on all exits.
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

# Copy a caller-provided local archive for tests, otherwise download the
# configured GitHub archive with curl or wget.
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

# Verify the downloaded archive only when the caller supplied an expected
# SHA-256 checksum.
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

# Extract the archive and return the single repository directory it created.
extract_archive() {
  local archive="$1"
  local candidate=""
  local repo_dir=""
  local repo_count=0

  tar -xzf "$archive" -C "$tmp_dir"

  for candidate in "$tmp_dir"/ai-assistant-stack-* "$tmp_dir"/token-saver-setup-*; do
    if [ -d "$candidate" ]; then
      repo_dir="$candidate"
      repo_count=$((repo_count + 1))
    fi
  done

  if [ "$repo_count" -ne 1 ]; then
    printf 'error: setup archive did not extract to one ai-assistant-stack directory\n' >&2
    exit 1
  fi

  printf '%s\n' "$repo_dir"
}

# Download, optionally verify, and dispatch from the extracted archive into the
# full installer.
archive="$tmp_dir/ai-assistant-stack.tar.gz"
download_archive "$archive"
verify_archive "$archive"

# Support checksum-only dry-run tests for local archive fixtures without
# executing the installer payload.
if [ "${1:-}" = "--dry-run" ] && [ -n "$LOCAL_ARCHIVE" ]; then
  printf 'dry-run: verified local bootstrap archive\n'
  exit 0
fi

# Preserve prompt TTY detection for install.sh and replace the bootstrap process
# with the real installer.
repo_dir="$(extract_archive "$archive")"
export TOKEN_SAVER_PROMPT_TTY="$PROMPT_TTY"
exec bash "$repo_dir/scripts/install.sh" "$@"
