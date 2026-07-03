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

# Verify instruction-file installs print the user-visible actions they perform.
install_output_names_instruction_file_actions() {
  local home="$tmp/home-output"
  local output
  mkdir -p "$home"

  output="$(
    HOME="$home" bash "$ROOT/scripts/install.sh" --non-interactive --tools both
  )"

  assert_contains "$output" "Selected tools"
  assert_contains "$output" "OK both"
  assert_contains "$output" "Installed $home/.codex/AGENTS.md"
  assert_contains "$output" "Installed $home/.claude/CLAUDE.md"
  assert_contains "$output" "Installed Git template post-checkout hook"
  assert_contains "$output" "Configured git init.templateDir"
}

# Verify target-mode installs print stack setup progress before instruction-file
# output.
target_install_output_names_stack_actions() {
  local home="$tmp/home-target-output"
  local output
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  chmod +x "$home/bin/codex"

  output="$(
    HOME="$home" PATH="$home/bin:$PATH" CONTEXT7_API_KEY=test-key \
      bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets codex-desktop
  )"

  assert_contains "$output" "Preflight selected targets"
  assert_contains "$output" "Install LeanCTX"
  assert_contains "$output" "Configure Context7"
  assert_contains "$output" "Install Caveman"
  assert_contains "$output" "Install Superpowers"
  assert_contains "$output" "Install complete"
}

# Run visible-output scenarios.
install_output_names_instruction_file_actions
target_install_output_names_stack_actions

printf 'install-visible-output.sh: OK\n'
