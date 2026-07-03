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

# Run the managed uninstall scenario.
install_and_uninstall_managed_files_only

printf 'install-uninstall-prompt.sh: OK\n'
