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

# Verify target-mode setup fails during preflight when Context7 credentials are
# missing, before any stack setup begins.
context7_credentials_required() {
  local home="$tmp/home-context7"
  local output
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  chmod +x "$home/bin/codex"

  if HOME="$home" PATH="$home/bin:$PATH" \
    bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets codex >"$tmp/context7.out" 2>"$tmp/context7.err"; then
    printf 'missing Context7 credentials unexpectedly succeeded\n' >&2
    exit 1
  fi

  output="$(cat "$tmp/context7.out")$(cat "$tmp/context7.err")"
  assert_contains "$output" "Preflight selected targets"
  assert_contains "$output" "missing prerequisite for selected targets: Context7 API key"
  assert_contains "$(cat "$tmp/context7.err")" "export CONTEXT7_API_KEY=\"your-context7-api-key\""
  assert_not_contains "$output" "Install LeanCTX"
  assert_not_contains "$output" "Configure Context7"
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
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" CONTEXT7_API_KEY=test-key \
      bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets codex
  )"
  log="$home/.agents/install.log"

  assert_contains "$output" "Install LeanCTX"
  assert_contains "$output" "Dry run Configure LeanCTX setup"
  assert_contains "$output" "Dry run Disable LeanCTX proxy"
  assert_contains "$output" "Configure Context7"
  assert_contains "$output" "Install Caveman"
  assert_contains "$output" "Dry run Install all Caveman skills for Codex"
  assert_contains "$output" "Install Superpowers"
  assert_contains "$output" "Dry run Configure Context7 for Codex"
  assert_not_contains "$output" "Configure LeanCTX tools"
  assert_contains "$(cat "$log")" "lean-ctx setup"
  assert_contains "$(cat "$log")" "leanctx_setup_project=$ROOT"
  assert_contains "$(cat "$log")" 'cd "$1"'
  assert_contains "$(cat "$log")" 'cd "$HOME"'
  assert_not_contains "$(cat "$log")" "LEAN_CTX_PROJECT_ROOT"
  assert_contains "$(cat "$log")" "lean-ctx proxy disable"
  assert_contains "$(cat "$log")" "npx skills add JuliusBrussee/caveman --yes --global"
  assert_contains "$(cat "$log")" "codex mcp add context7"
  assert_contains "$(cat "$log")" "--api-key <redacted>"
  assert_not_contains "$(cat "$log")" "lean-ctx tools minimal"
  assert_not_contains "$(cat "$log")" "lean-ctx proxy enable"
}

# Verify Claude Desktop targets configure Context7 through the Desktop MCP config
# path without requiring the Claude Code CLI.
dry_run_prints_stack_steps_for_claude_desktop() {
  local home="$tmp/home-stack-claude-desktop"
  local output log config
  mkdir -p "$home/bin" "$home/Applications/Claude.app"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/node"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/npx"
  chmod +x "$home/bin/node" "$home/bin/npx"
  config="$home/Library/Application Support/Claude/claude_desktop_config.json"

  output="$(
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" CONTEXT7_API_KEY=test-key \
      CLAUDE_DESKTOP_APP_PATH="$home/Applications/Claude.app" \
      CLAUDE_DESKTOP_CONFIG_PATH="$config" \
      bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets claude
  )"
  log="$home/.agents/install.log"

  assert_contains "$output" "Dry run Configure Context7 for Claude Desktop"
  assert_contains "$output" "$config"
  assert_contains "$output" "Skipped Claude Code CLI not found"
  assert_contains "$(cat "$log")" "update_claude_desktop_config=$config server=context7"
}

# Verify the Claude Desktop config writer preserves existing MCP servers and
# merges the managed Context7 entry.
claude_desktop_config_is_merged() {
  local home="$tmp/home-claude-desktop-merge"
  local output config node_path
  node_path="$(command -v node || true)"
  [ -n "$node_path" ] || {
    printf 'node is required for this test\n' >&2
    exit 1
  }

  mkdir -p "$home/bin" "$home/Applications/Claude.app" "$home/Library/Application Support/Claude"
  ln -s "$node_path" "$home/bin/node"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/npx"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/lean-ctx"
  chmod +x "$home/bin/npx" "$home/bin/lean-ctx"
  config="$home/Library/Application Support/Claude/claude_desktop_config.json"
  printf '{"theme":"dark","mcpServers":{"existing":{"command":"true"}}}\n' > "$config"

  output="$(
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" CONTEXT7_API_KEY=test-key \
      CLAUDE_DESKTOP_APP_PATH="$home/Applications/Claude.app" \
      CLAUDE_DESKTOP_CONFIG_PATH="$config" \
      bash "$ROOT/scripts/install.sh" --non-interactive --targets claude
  )"

  assert_contains "$output" "OK Configure Context7 for Claude Desktop $config"
  assert_not_contains "$output" "Configure Context7 for Claude Code"
  "$node_path" -e '
const fs = require("fs");
const config = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
if (config.theme !== "dark") process.exit(1);
if (!config.mcpServers.existing) process.exit(2);
if (config.mcpServers.context7.command !== "npx") process.exit(3);
if (config.mcpServers.context7.env.CONTEXT7_API_KEY !== "test-key") process.exit(4);
' "$config"
}

# Run the stack-tool scenarios.
context7_credentials_required
dry_run_prints_stack_steps_for_codex
dry_run_prints_stack_steps_for_claude_desktop
claude_desktop_config_is_merged

printf 'install-stack-tools.sh: OK\n'
