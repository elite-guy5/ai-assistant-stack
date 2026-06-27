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

assert_not_contains() {
  case "$1" in
    *"$2"*)
      printf 'expected output not to contain: %s\noutput was:\n%s\n' "$2" "$1" >&2
      exit 1
      ;;
    *) ;;
  esac
}

requires_tools_in_non_interactive_mode() {
  local home="$tmp/home-requires-tools"
  mkdir -p "$home"

  if HOME="$home" bash "$ROOT/scripts/install.sh" --dry-run --non-interactive >"$tmp/requires.out" 2>"$tmp/requires.err"; then
    printf 'non-interactive install without --tools unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/requires.err")" "--tools is required in non-interactive mode"
}

dry_run_codex_only_has_no_third_party_actions() {
  local home="$tmp/home-codex"
  local output
  mkdir -p "$home"

  output="$(
    HOME="$home" bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --tools codex
  )"

  assert_contains "$output" "Selected tools: codex"
  assert_contains "$output" "$home/.codex/AGENTS.md"
  assert_contains "$output" "$home/.codex/AGENTS.project-template.md"
  assert_contains "$output" "$home/.agents/git-template/hooks/post-checkout"
  assert_not_contains "$output" "$home/.claude/CLAUDE.md"
  assert_not_contains "$output" "package-manager install"
  assert_not_contains "$output" "external tool install"
  assert_not_contains "$output" "third-party setup"
}

removed_flags_are_rejected() {
  local home="$tmp/home-removed-flags"
  mkdir -p "$home"

  if HOME="$home" bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --tools both --ai-apps codex >"$tmp/removed.out" 2>"$tmp/removed.err"; then
    printf 'removed --ai-apps flag unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/removed.err")" "unknown option: --ai-apps"
}

interactive_selection_can_choose_codex() {
  local home="$tmp/home-interactive"
  local output
  mkdir -p "$home"

  output="$(
    printf '1\nn\n' | HOME="$home" bash "$ROOT/scripts/install.sh" --dry-run
  )"

  assert_contains "$output" "Which tool should this installer configure?"
  assert_contains "$output" "Selected tools: codex"
  assert_contains "$output" "$home/.codex/AGENTS.md"
  assert_not_contains "$output" "$home/.claude/CLAUDE.md"
}

requires_tools_in_non_interactive_mode
dry_run_codex_only_has_no_third_party_actions
removed_flags_are_rejected
interactive_selection_can_choose_codex

printf 'install-dry-run.sh: OK\n'
