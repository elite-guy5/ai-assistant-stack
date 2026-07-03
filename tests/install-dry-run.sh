#!/usr/bin/env bash
set -euo pipefail

# Locate the repository and create an isolated temporary workspace for this test
# file.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Assert that command output includes an expected substring.
assert_contains() {
  case "$1" in
    *"$2"*) ;;
    *)
      printf 'expected output to contain: %s\noutput was:\n%s\n' "$2" "$1" >&2
      exit 1
      ;;
  esac
}

# Assert that command output does not include an unwanted substring.
assert_not_contains() {
  case "$1" in
    *"$2"*)
      printf 'expected output not to contain: %s\noutput was:\n%s\n' "$2" "$1" >&2
      exit 1
      ;;
    *) ;;
  esac
}

# Verify non-interactive installs fail before doing work when no selection is
# provided.
requires_tools_in_non_interactive_mode() {
  local home="$tmp/home-requires-tools"
  mkdir -p "$home"

  if HOME="$home" bash "$ROOT/scripts/install.sh" --dry-run --non-interactive >"$tmp/requires.out" 2>"$tmp/requires.err"; then
    printf 'non-interactive install without --tools unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/requires.err")" "--targets or --tools is required in non-interactive mode"
}

# Verify legacy codex-only dry-run output stays limited to instruction-file and
# hook actions.
dry_run_codex_only_has_no_third_party_actions() {
  local home="$tmp/home-codex"
  local output
  mkdir -p "$home"

  output="$(
    HOME="$home" bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --tools codex
  )"

  assert_contains "$output" "Selected tools"
  assert_contains "$output" "OK codex"
  assert_contains "$output" "$home/.codex/AGENTS.md"
  assert_contains "$output" "$home/.codex/AGENTS.project-template.md"
  assert_contains "$output" "$home/.agents/git-template/hooks/post-checkout"
  assert_not_contains "$output" "$home/.claude/CLAUDE.md"
  assert_not_contains "$output" "package-manager install"
  assert_not_contains "$output" "external tool install"
  assert_not_contains "$output" "third-party setup"
}

# Verify removed installer flags fail loudly instead of being accepted silently.
removed_flags_are_rejected() {
  local home="$tmp/home-removed-flags"
  mkdir -p "$home"

  if HOME="$home" bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --tools both --ai-apps codex >"$tmp/removed.out" 2>"$tmp/removed.err"; then
    printf 'removed --ai-apps flag unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/removed.err")" "unknown option: --ai-apps"
}

# Verify interactive target selection can choose the Codex product target
# with Space/Enter and decline current-repo hook installation through stdin.
interactive_selection_can_choose_codex() {
  local home="$tmp/home-interactive"
  local output
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  chmod +x "$home/bin/codex"

  output="$(
    printf 'n\n' | HOME="$home" PATH="$home/bin:$PATH" CONTEXT7_API_KEY=test-key TOKEN_SAVER_TEST_KEYS=$' \n' \
      bash "$ROOT/scripts/install.sh" --dry-run
  )"

  assert_contains "$output" "Select targets to configure"
  assert_contains "$output" "> ○ Codex"
  assert_contains "$output" "> ● Codex"
  assert_contains "$output" "Selected targets"
  assert_contains "$output" "OK Codex"
  assert_contains "$output" "Selected tools"
  assert_contains "$output" "OK codex"
  assert_contains "$output" "$home/.codex/AGENTS.md"
  assert_not_contains "$output" "$home/.claude/CLAUDE.md"
}

# Run the dry-run behavior scenarios.
requires_tools_in_non_interactive_mode
dry_run_codex_only_has_no_third_party_actions
removed_flags_are_rejected
interactive_selection_can_choose_codex

printf 'install-dry-run.sh: OK\n'
