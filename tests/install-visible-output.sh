#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYSTEM_PATH="/usr/bin:/bin:/usr/sbin:/sbin"
NODE_PATH="/usr/local/bin:$SYSTEM_PATH"

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if ! printf '%s\n' "$haystack" | grep -Fq "$needle"; then
    printf 'expected output to contain: %s\n' "$needle" >&2
    exit 1
  fi
}

assert_count() {
  local haystack="$1"
  local needle="$2"
  local expected="$3"
  local count

  count="$(printf '%s\n' "$haystack" | grep -Fc "$needle" || true)"
  if [ "$count" != "$expected" ]; then
    printf 'expected %s occurrence(s) of %s, found %s\n' "$expected" "$needle" "$count" >&2
    exit 1
  fi
}

make_rtk_stub() {
  local bin_dir="$1"
  local mode="${2:-success}"

  cat > "$bin_dir/rtk" <<SH
#!/usr/bin/env bash
set -eu
if [ "\${1:-}" = "--version" ]; then
  printf 'rtk-test-version\\n'
  exit 0
fi
if [ "\${1:-}" = "init" ]; then
  printf 'rtk init stdout visible\\n'
  printf 'rtk init stderr visible\\n' >&2
  if [ "$mode" = "fail" ]; then
    exit 7
  fi
  mkdir -p "\$HOME/.claude" "\$HOME/.codex"
  printf '# Claude\\n@RTK.md\\n' > "\$HOME/.claude/CLAUDE.md"
  printf 'Hook-Based Usage\\n' > "\$HOME/.claude/RTK.md"
  printf '# Codex\\n@RTK.md\\n' > "\$HOME/.codex/AGENTS.md"
  printf 'Always prefix shell commands with \`rtk\`\\n' > "\$HOME/.codex/RTK.md"
fi
exit 0
SH
  chmod +x "$bin_dir/rtk"
}

make_npx_stub() {
  local bin_dir="$1"
  local mode="${2:-success}"

  cat > "$bin_dir/npx" <<SH
#!/usr/bin/env bash
set -eu
case " \$* " in
  *" github:JuliusBrussee/caveman "*)
    printf 'caveman npx installer stdout visible\\n'
    printf 'caveman npx installer stderr visible\\n' >&2
    ;;
  *)
    printf 'caveman skills stdout visible\\n'
    printf 'caveman skills stderr visible\\n' >&2
    ;;
esac
if [ "$mode" = "fail" ]; then
  exit 9
fi
exit 0
SH
  chmod +x "$bin_dir/npx"
}

make_claude_stub() {
  local bin_dir="$1"

  cat > "$bin_dir/claude" <<'SH'
#!/usr/bin/env bash
set -eu
printf 'caveman claude stdout visible\n'
printf 'caveman claude stderr visible\n' >&2
exit 0
SH
  chmod +x "$bin_dir/claude"
}

make_agent_stubs() {
  local bin_dir="$1"
  shift

  for name in "$@"; do
    printf '#!/usr/bin/env sh\nexit 0\n' > "$bin_dir/$name"
    chmod +x "$bin_dir/$name"
  done
}

shell_rtk_output_is_visible() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/bin" "$tmp/home"
  make_rtk_stub "$tmp/bin"
  make_agent_stubs "$tmp/bin" claude

  output="$(
    HOME="$tmp/home" PATH="$tmp/bin:$NODE_PATH" TOKEN_SAVER_MANIFEST="$tmp/home/.agents/install_manifest.json" \
      bash "$ROOT/scripts/install.sh" --non-interactive --skip-caveman --rtk-agents claude --rtk-mode manual 2>&1
  )"

  assert_contains "$output" "rtk init stdout visible"
  assert_contains "$output" "rtk init stderr visible"
}

shell_rtk_failure_is_visible_and_stops_install() {
  local tmp output status
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/bin" "$tmp/home"
  make_rtk_stub "$tmp/bin" fail
  make_agent_stubs "$tmp/bin" claude

  set +e
  output="$(
    HOME="$tmp/home" PATH="$tmp/bin:$NODE_PATH" TOKEN_SAVER_MANIFEST="$tmp/home/.agents/install_manifest.json" \
      bash "$ROOT/scripts/install.sh" --non-interactive --skip-caveman --rtk-agents claude --rtk-mode manual 2>&1
  )"
  status=$?
  set -e

  if [ "$status" = "0" ]; then
    printf 'failing RTK child installer did not stop parent installer\n' >&2
    exit 1
  fi
  assert_contains "$output" "rtk init stdout visible"
  assert_contains "$output" "rtk init stderr visible"
}

shell_caveman_output_is_visible_once() {
  local tmp output
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/bin" "$tmp/home"
  make_npx_stub "$tmp/bin"
  make_claude_stub "$tmp/bin"

  output="$(
    HOME="$tmp/home" PATH="$tmp/bin:$SYSTEM_PATH" TOKEN_SAVER_MANIFEST="$tmp/home/.agents/install_manifest.json" \
      bash "$ROOT/scripts/install.sh" --non-interactive --skip-rtk 2>&1
  )"

  assert_count "$output" "caveman claude stdout visible" 2
  assert_count "$output" "caveman claude stderr visible" 2
  assert_count "$output" "caveman skills stdout visible" 1
  assert_count "$output" "caveman skills stderr visible" 1
}

pwsh_child_output_is_visible() {
  command -v pwsh >/dev/null 2>&1 || return 0

  local tmp output status pwsh_bin
  pwsh_bin="$(command -v pwsh)"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/bin" "$tmp/home"
  make_rtk_stub "$tmp/bin"
  make_npx_stub "$tmp/bin"
  make_agent_stubs "$tmp/bin" claude
  make_claude_stub "$tmp/bin"

  output="$(
    HOME="$tmp/home" PATH="$tmp/bin:$SYSTEM_PATH" TOKEN_SAVER_HOME="$tmp/home" TOKEN_SAVER_MANIFEST="$tmp/home/.agents/install_manifest.json" \
      "$pwsh_bin" -NoProfile -File "$ROOT/scripts/install.ps1" -NonInteractive -RtkAgents claude -RtkMode manual 2>&1
  )"

  assert_contains "$output" "rtk init stdout visible"
  assert_contains "$output" "rtk init stderr visible"
  assert_count "$output" "caveman claude stdout visible" 2
  assert_count "$output" "caveman claude stderr visible" 2
  assert_count "$output" "caveman skills stdout visible" 1
  assert_count "$output" "caveman skills stderr visible" 1

  make_rtk_stub "$tmp/bin" fail
  set +e
  output="$(
    HOME="$tmp/home-fail" PATH="$tmp/bin:$SYSTEM_PATH" TOKEN_SAVER_HOME="$tmp/home-fail" TOKEN_SAVER_MANIFEST="$tmp/home-fail/.agents/install_manifest.json" \
      "$pwsh_bin" -NoProfile -File "$ROOT/scripts/install.ps1" -NonInteractive -SkipCaveman -RtkAgents claude -RtkMode manual 2>&1
  )"
  status=$?
  set -e

  if [ "$status" = "0" ]; then
    printf 'failing PowerShell RTK child installer did not stop parent installer\n' >&2
    exit 1
  fi
  assert_contains "$output" "rtk init stdout visible"
  assert_contains "$output" "rtk init stderr visible"
}

shell_rtk_output_is_visible
shell_rtk_failure_is_visible_and_stops_install
shell_caveman_output_is_visible_once
pwsh_child_output_is_visible

printf 'install-visible-output.sh: OK\n'
