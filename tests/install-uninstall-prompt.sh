#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if ! command -v expect >/dev/null 2>&1; then
  printf 'expect is required for this test\n' >&2
  exit 1
fi

HOME="$tmp/home"
mkdir -p "$HOME"

expect_script="$tmp/uninstall.exp"
cat > "$expect_script" <<'EOF'
set timeout 10
spawn bash scripts/install.sh --dry-run --uninstall
expect -exact {Reset all instruction files? (y/n) [n]: }
send "n\r"
expect -exact {Reset only project instruction sections? (y/n) [n]: }
send "n\r"
expect -exact {Remove project templates? (y/n) [n]: }
send "n\r"
expect -exact {Remove seeding? (y/n) [n]: }
send "n\r"
expect -exact {Remove ignore optimizer? (y/n) [n]: }
send "n\r"
expect -exact {Remove rtk? (y/n) [n]: }
send "n\r"
expect -exact {Remove caveman? (y/n) [n]: }
send "n\r"
expect eof
EOF

output_file="$tmp/uninstall-output.txt"
if ! (cd "$ROOT" && HOME="$HOME" expect "$expect_script" 2>&1 | tee "$output_file"); then
  printf 'uninstall prompt failed to complete successfully\n' >&2
  exit 1
fi
output="$(cat "$output_file")"

if printf '%s\n' "$output" | grep -q 'unbound variable'; then
  printf 'uninstall prompt crashed with unbound variable\n' >&2
  exit 1
fi

if ! printf '%s\n' "$output" | grep -q 'uninstall complete'; then
  printf 'uninstall prompt did not complete successfully\n' >&2
  exit 1
fi

printf 'install-uninstall-prompt.sh: OK\n'