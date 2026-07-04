#!/usr/bin/env bash
set -euo pipefail

# Locate the repository and create an isolated temporary workspace for this test
# file.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Assert that a path exists.
assert_exists() {
  [ -e "$1" ] || {
    printf 'expected path to exist: %s\n' "$1" >&2
    exit 1
  }
}

# Assert that a path does not exist.
assert_not_exists() {
  [ ! -e "$1" ] || {
    printf 'expected path not to exist: %s\n' "$1" >&2
    exit 1
  }
}

# Assert that text contains a substring.
assert_contains() {
  case "$1" in
    *"$2"*) ;;
    *)
      printf 'expected output to contain: %s\noutput was:\n%s\n' "$2" "$1" >&2
      exit 1
      ;;
  esac
}

# Assert that a file contains an expected substring.
assert_file_contains() {
  assert_contains "$(cat "$1")" "$2"
}

# Count timestamped backups for one file.
backup_count_for() {
  find "$(dirname "$1")" -name "$(basename "$1").token-saver-backup-*" | wc -l | tr -d ' '
}

# Verify uninstall removes only installer-managed files and preserves a
# pre-existing user-owned Codex instruction file.
install_and_uninstall_managed_files_only() {
  local home="$tmp/home-uninstall"
  mkdir -p "$home/.codex"
  printf 'user owned\n' > "$home/.codex/AGENTS.md"

  HOME="$home" bash "$ROOT/scripts/install.sh" --non-interactive --tools claude >/dev/null

  assert_exists "$home/.claude/CLAUDE.md"
  assert_exists "$home/.claude/CLAUDE.project-template.md"
  assert_exists "$home/.agents/scripts/seed-project-instructions.sh"
  assert_exists "$home/.agents/git-template/hooks/post-checkout"

  HOME="$home" bash "$ROOT/scripts/install.sh" --non-interactive --uninstall >/dev/null

  assert_not_exists "$home/.claude/CLAUDE.md"
  assert_not_exists "$home/.claude/CLAUDE.project-template.md"
  assert_not_exists "$home/.agents/scripts/seed-project-instructions.sh"
  assert_not_exists "$home/.agents/git-template/hooks/post-checkout"
  assert_exists "$home/.codex/AGENTS.md"
}

# Verify interactive installs ask before replacing an existing instruction file
# and replace only after the user answers yes.
interactive_replace_prompt_accepts_yes() {
  local home="$tmp/home-replace-yes"
  local output backup_count
  mkdir -p "$home/.codex"
  printf 'user owned\n' > "$home/.codex/AGENTS.md"

  output="$(
    cd "$home"
    printf 'y\n' | HOME="$home" bash "$ROOT/scripts/install.sh" --tools codex
  )"

  assert_contains "$output" "Replace existing $home/.codex/AGENTS.md?"
  assert_contains "$output" "Backing up $home/.codex/AGENTS.md"
  assert_file_contains "$home/.codex/AGENTS.md" "# AGENTS.md"
  backup_count="$(backup_count_for "$home/.codex/AGENTS.md")"
  [ "$backup_count" = "1" ] || {
    printf 'expected one AGENTS.md backup, found %s\n' "$backup_count" >&2
    exit 1
  }
}

# Verify answering no keeps the existing instruction file unchanged.
interactive_replace_prompt_accepts_no() {
  local home="$tmp/home-replace-no"
  local output backup_count
  mkdir -p "$home/.codex"
  printf 'user owned\n' > "$home/.codex/AGENTS.md"

  output="$(
    cd "$home"
    printf 'n\n' | HOME="$home" bash "$ROOT/scripts/install.sh" --tools codex
  )"

  assert_contains "$output" "Replace existing $home/.codex/AGENTS.md?"
  assert_contains "$output" "Skipped Existing $home/.codex/AGENTS.md"
  assert_file_contains "$home/.codex/AGENTS.md" "user owned"
  backup_count="$(backup_count_for "$home/.codex/AGENTS.md")"
  [ "$backup_count" = "0" ] || {
    printf 'expected no AGENTS.md backups, found %s\n' "$backup_count" >&2
    exit 1
  }
}

# Verify non-interactive installs still skip existing instruction files unless
# an overwrite flag is explicit.
non_interactive_existing_file_still_skips() {
  local home="$tmp/home-noninteractive-skip"
  local output backup_count
  mkdir -p "$home/.codex"
  printf 'user owned\n' > "$home/.codex/AGENTS.md"

  output="$(
    cd "$home"
    HOME="$home" bash "$ROOT/scripts/install.sh" --non-interactive --tools codex
  )"

  assert_contains "$output" "Skipped Existing $home/.codex/AGENTS.md"
  assert_file_contains "$home/.codex/AGENTS.md" "user owned"
  backup_count="$(backup_count_for "$home/.codex/AGENTS.md")"
  [ "$backup_count" = "0" ] || {
    printf 'expected no AGENTS.md backups, found %s\n' "$backup_count" >&2
    exit 1
  }
}

# Verify explicit overwrite flags keep replacing without prompting.
overwrite_replaces_without_prompt() {
  local home="$tmp/home-overwrite"
  local output backup_count
  mkdir -p "$home/.codex"
  printf 'user owned\n' > "$home/.codex/AGENTS.md"

  output="$(
    cd "$home"
    HOME="$home" bash "$ROOT/scripts/install.sh" --non-interactive --tools codex --overwrite-global-instructions
  )"

  assert_contains "$output" "Backing up $home/.codex/AGENTS.md"
  assert_file_contains "$home/.codex/AGENTS.md" "# AGENTS.md"
  backup_count="$(backup_count_for "$home/.codex/AGENTS.md")"
  [ "$backup_count" = "1" ] || {
    printf 'expected one AGENTS.md backup, found %s\n' "$backup_count" >&2
    exit 1
  }
}

# Run the managed install/uninstall and prompt scenarios.
install_and_uninstall_managed_files_only
interactive_replace_prompt_accepts_yes
interactive_replace_prompt_accepts_no
non_interactive_existing_file_still_skips
overwrite_replaces_without_prompt

printf 'install-uninstall-prompt.sh: OK\n'
