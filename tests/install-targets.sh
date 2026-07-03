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

# Verify Codex product targets derive the legacy codex tool selector.
target_mode_derives_codex_tools() {
  local home="$tmp/home-codex-targets"
  local output
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  chmod +x "$home/bin/codex"

  output="$(
    HOME="$home" PATH="$home/bin:$PATH" CONTEXT7_API_KEY=test-key \
      bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets codex
  )"

  assert_contains "$output" "Selected targets"
  assert_contains "$output" "OK Codex"
  assert_contains "$output" "Selected tools"
  assert_contains "$output" "OK codex"
}

# Verify mixed Codex and Claude product targets derive the legacy both tool
# selector while showing only product-level selections.
target_mode_derives_both_tools() {
  local home="$tmp/home-both-targets"
  local output
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/claude"
  chmod +x "$home/bin/codex" "$home/bin/claude"

  output="$(
    HOME="$home" PATH="$home/bin:$PATH" CONTEXT7_API_KEY=test-key \
      bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets codex,claude
  )"

  assert_contains "$output" "Selected targets"
  assert_contains "$output" "OK Codex"
  assert_contains "$output" "OK Claude"
  assert_contains "$output" "Selected tools"
  assert_contains "$output" "OK both"
}

# Verify old surface-level target names remain accepted as aliases while the
# normalized output stays product-level.
legacy_surface_targets_normalize_to_products() {
  local home="$tmp/home-legacy-targets"
  local output
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/claude"
  chmod +x "$home/bin/codex" "$home/bin/claude"

  output="$(
    HOME="$home" PATH="$home/bin:$PATH" CONTEXT7_API_KEY=test-key \
      bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets codex-desktop,claude-vscode
  )"

  assert_contains "$output" "Selected targets"
  assert_contains "$output" "OK Codex"
  assert_contains "$output" "OK Claude"
  assert_contains "$output" "OK both"
}

# Verify unsupported target names are rejected during argument parsing.
invalid_target_is_rejected() {
  local home="$tmp/home-invalid-target"
  mkdir -p "$home"

  if HOME="$home" bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets codex-mobile >"$tmp/invalid.out" 2>"$tmp/invalid.err"; then
    printf 'invalid target unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/invalid.err")" "invalid --targets value: codex-mobile"
}

# Verify non-interactive mode requires either --targets or --tools.
non_interactive_requires_targets_or_tools() {
  local home="$tmp/home-requires-selection"
  mkdir -p "$home"

  if HOME="$home" bash "$ROOT/scripts/install.sh" --dry-run --non-interactive >"$tmp/requires.out" 2>"$tmp/requires.err"; then
    printf 'non-interactive install without selection unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/requires.err")" "--targets or --tools is required in non-interactive mode"
}

# Run target parsing and derivation scenarios.
target_mode_derives_codex_tools
target_mode_derives_both_tools
legacy_surface_targets_normalize_to_products
invalid_target_is_rejected
non_interactive_requires_targets_or_tools

# Verify the interactive checklist starts empty, uses Space to toggle, and has
# only product-level Codex and Claude options.
interactive_selector_uses_space_toggles() {
  local home="$tmp/home-selector"
  local output
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  chmod +x "$home/bin/codex"

  output="$(
    printf 'n\n' | HOME="$home" PATH="$home/bin:$PATH" CONTEXT7_API_KEY=test-key TOKEN_SAVER_TEST_KEYS=$' \n' \
      bash "$ROOT/scripts/install.sh" --dry-run
  )"

  assert_contains "$output" "> ○ Codex"
  assert_contains "$output" "  ○ Claude"
  assert_contains "$output" "> ● Codex"
  assert_contains "$output" "Space toggles"
  case "$output" in
    *"Codex Desktop"*|*"Codex VS Code"*|*"Claude Desktop"*|*"Claude Code"*|*"All"*|*"Selection [5]"*)
      printf 'legacy target menu appeared in output:\n%s\n' "$output" >&2
      exit 1
      ;;
  esac
}

interactive_selector_uses_space_toggles

# Verify terminal arrow escape sequences move focus to Claude before Space
# toggles the selected row. Some terminals use ESC [ B and others use ESC O B.
interactive_selector_supports_arrow_keys() {
  local home="$tmp/home-arrows"
  local output
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/claude"
  chmod +x "$home/bin/claude"

  output="$(
    printf 'n\n' | HOME="$home" PATH="$home/bin:$PATH" CONTEXT7_API_KEY=test-key TOKEN_SAVER_TEST_KEYS=$'\033[B \n' \
      bash "$ROOT/scripts/install.sh" --dry-run
  )"

  assert_contains "$output" "> ○ Claude"
  assert_contains "$output" "> ● Claude"
  assert_contains "$output" "OK Claude"

  output="$(
    printf 'n\n' | HOME="$home" PATH="$home/bin:$PATH" CONTEXT7_API_KEY=test-key TOKEN_SAVER_TEST_KEYS=$'\033OB \n' \
      bash "$ROOT/scripts/install.sh" --dry-run
  )"

  assert_contains "$output" "> ○ Claude"
  assert_contains "$output" "> ● Claude"
  assert_contains "$output" "OK Claude"
}

interactive_selector_supports_arrow_keys

printf 'install-targets.sh: OK\n'
