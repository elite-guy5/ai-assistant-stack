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

# Verify target-mode stack setup fails before configuration when Context7
# credentials are missing.
context7_credentials_required() {
  local home="$tmp/home-context7"
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  chmod +x "$home/bin/codex"

  if HOME="$home" PATH="$home/bin:$PATH" \
    bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets codex-desktop >"$tmp/context7.out" 2>"$tmp/context7.err"; then
    printf 'missing Context7 credentials unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/context7.err")" "Context7 credentials are required before stack configuration."
  assert_contains "$(cat "$tmp/context7.err")" "export CONTEXT7_API_KEY=\"your-context7-api-key\""
}

# Verify Codex target dry-run output includes every stack setup step with
# secrets redacted.
dry_run_prints_stack_steps_for_codex() {
  local home="$tmp/home-stack-codex"
  local output log
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  chmod +x "$home/bin/codex"

  output="$(
    HOME="$home" PATH="$home/bin:$PATH" CONTEXT7_API_KEY=test-key \
      bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets codex-desktop
  )"
  log="$home/.agents/install.log"

  assert_contains "$output" "Install LeanCTX"
  assert_contains "$output" "Configure Context7"
  assert_contains "$output" "Install Caveman"
  assert_contains "$output" "Install Superpowers"
  assert_contains "$output" "Dry run Configure Context7 for Codex"
  assert_contains "$(cat "$log")" "codex mcp add context7"
  assert_contains "$(cat "$log")" "--api-key <redacted>"
}

# Run the stack-tool scenarios.
context7_credentials_required
dry_run_prints_stack_steps_for_codex

printf 'install-stack-tools.sh: OK\n'
