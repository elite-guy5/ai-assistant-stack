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

install_output_names_instruction_file_actions() {
  local home="$tmp/home-output"
  local output
  mkdir -p "$home"

  output="$(
    HOME="$home" bash "$ROOT/scripts/install.sh" --non-interactive --tools both
  )"

  assert_contains "$output" "Selected tools: both"
  assert_contains "$output" "Installed $home/.codex/AGENTS.md"
  assert_contains "$output" "Installed $home/.claude/CLAUDE.md"
  assert_contains "$output" "Installed Git template post-checkout hook"
  assert_contains "$output" "Configured git init.templateDir"
}

install_output_names_instruction_file_actions

printf 'install-visible-output.sh: OK\n'
