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

target_mode_derives_codex_tools() {
  local home="$tmp/home-codex-targets"
  local output
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/code"
  chmod +x "$home/bin/codex" "$home/bin/code"

  output="$(
    HOME="$home" PATH="$home/bin:$PATH" CONTEXT7_API_KEY=test-key \
      bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets codex-desktop,codex-vscode
  )"

  assert_contains "$output" "Selected targets: codex-desktop,codex-vscode"
  assert_contains "$output" "Selected tools: codex"
}

target_mode_derives_both_tools() {
  local home="$tmp/home-both-targets"
  local output
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/claude"
  chmod +x "$home/bin/codex" "$home/bin/claude"

  output="$(
    HOME="$home" PATH="$home/bin:$PATH" CONTEXT7_API_KEY=test-key \
      bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets codex-desktop,claude-desktop
  )"

  assert_contains "$output" "Selected targets: codex-desktop,claude-desktop"
  assert_contains "$output" "Selected tools: both"
}

invalid_target_is_rejected() {
  local home="$tmp/home-invalid-target"
  mkdir -p "$home"

  if HOME="$home" bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets codex-mobile >"$tmp/invalid.out" 2>"$tmp/invalid.err"; then
    printf 'invalid target unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/invalid.err")" "invalid --targets value: codex-mobile"
}

non_interactive_requires_targets_or_tools() {
  local home="$tmp/home-requires-selection"
  mkdir -p "$home"

  if HOME="$home" bash "$ROOT/scripts/install.sh" --dry-run --non-interactive >"$tmp/requires.out" 2>"$tmp/requires.err"; then
    printf 'non-interactive install without selection unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/requires.err")" "--targets or --tools is required in non-interactive mode"
}

target_mode_derives_codex_tools
target_mode_derives_both_tools
invalid_target_is_rejected
non_interactive_requires_targets_or_tools

printf 'install-targets.sh: OK\n'
