#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_contains() {
  case "$1" in
    *"$2"*) ;;
    *)
      printf 'expected output to contain: %s\noutput was:\n%s\n' "$2" "$1" >&2
      exit 1
      ;;
  esac
}

assert_not_exists() {
  [ ! -e "$1" ] || {
    printf 'expected path not to exist: %s\n' "$1" >&2
    exit 1
  }
}

missing_codex_stops_before_changes() {
  local home="$tmp/home-missing-codex"
  mkdir -p "$home"

  if HOME="$home" PATH="/usr/bin:/bin" CONTEXT7_API_KEY=test-key \
    bash "$ROOT/scripts/install.sh" --non-interactive --targets codex-desktop >"$tmp/codex.out" 2>"$tmp/codex.err"; then
    printf 'missing codex unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/codex.err")" "missing prerequisite for codex-desktop: codex"
  assert_contains "$(cat "$tmp/codex.err")" "No files or configuration were changed."
  assert_not_exists "$home/.codex/AGENTS.md"
  assert_not_exists "$home/.agents/scripts/seed-project-instructions.sh"
}

missing_vscode_stops_before_changes() {
  local home="$tmp/home-missing-code"
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  chmod +x "$home/bin/codex"

  if HOME="$home" PATH="$home/bin:/usr/bin:/bin" CONTEXT7_API_KEY=test-key \
    bash "$ROOT/scripts/install.sh" --non-interactive --targets codex-vscode >"$tmp/code.out" 2>"$tmp/code.err"; then
    printf 'missing code unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/code.err")" "missing prerequisite for codex-vscode: code"
  assert_contains "$(cat "$tmp/code.err")" "Install VS Code and enable the code shell command."
  assert_not_exists "$home/.codex/AGENTS.md"
}

missing_claude_stops_before_changes() {
  local home="$tmp/home-missing-claude"
  mkdir -p "$home"

  if HOME="$home" PATH="/usr/bin:/bin" CONTEXT7_API_KEY=test-key \
    bash "$ROOT/scripts/install.sh" --non-interactive --targets claude-desktop >"$tmp/claude.out" 2>"$tmp/claude.err"; then
    printf 'missing claude unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/claude.err")" "missing prerequisite for claude-desktop: claude"
  assert_not_exists "$home/.claude/CLAUDE.md"
}

missing_codex_stops_before_changes
missing_vscode_stops_before_changes
missing_claude_stops_before_changes

printf 'install-preflight.sh: OK\n'
