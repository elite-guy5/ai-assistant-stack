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

# Verify target-mode installs create a log and redact sensitive Context7 values.
target_mode_writes_log() {
  local home="$tmp/home-log"
  local output log
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  chmod +x "$home/bin/codex"

  output="$(
    HOME="$home" PATH="$home/bin:$PATH" CONTEXT7_API_KEY=secret-value \
      bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets codex
  )"
  log="$home/.agents/install.log"

  [ -f "$log" ] || {
    printf 'expected log file: %s\n' "$log" >&2
    exit 1
  }

  assert_contains "$output" "Initialize install log"
  assert_contains "$output" "Log $log"
  assert_contains "$(cat "$log")" "selected_targets=codex"
  assert_contains "$(cat "$log")" "selected_tools=codex"
  assert_contains "$(cat "$log")" "dry_run_command="
  assert_not_contains "$(cat "$log")" "secret-value"
  assert_contains "$(cat "$log")" "CONTEXT7_API_KEY=<redacted>"
}

# Run the logging scenario.
target_mode_writes_log

printf 'install-logging.sh: OK\n'
