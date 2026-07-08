#!/usr/bin/env bash
set -euo pipefail

# Locate the repository and create an isolated temporary workspace for this test
# file.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

NODE_PATH_BIN="$(command -v node || true)"
[ -n "$NODE_PATH_BIN" ] || {
  printf 'node is required for this test\n' >&2
  exit 1
}

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

assert_exists() {
  [ -e "$1" ] || {
    printf 'expected path to exist: %s\n' "$1" >&2
    exit 1
  }
}

# Run configure_claude_code_leanctx_routing in an isolated HOME with library
# helpers sourced, mirroring how install.sh drives the stack.
run_routing() {
  local home="$1"
  local dry="$2"
  HOME="$home" PATH="$home/bin:/usr/bin:/bin" agents_home="$home/.agents" dry_run="$dry" bash -c '
    set -eu
    ROOT="$1"
    install_log="$2"
    say() { printf "%s\n" "$*"; }
    run() { "$@"; }
    backup_path() { printf "%s.token-saver-backup-%s" "$1" "$(date +%Y%m%d%H%M%S)"; }
    tools=claude
    tool_enabled() {
      case "$tools:$1" in
        both:*|codex:codex|claude:claude) return 0 ;;
        *) return 1 ;;
      esac
    }
    . "$ROOT/scripts/lib/targets.sh"
    . "$ROOT/scripts/lib/logging.sh"
    . "$ROOT/scripts/lib/stack-tools.sh"
    configure_claude_code_leanctx_routing
  ' sh "$ROOT" "$home/.agents/install.log"
}

# Seed an isolated HOME with a post-LeanCTX-setup settings.json and CLAUDE.md so
# the routing step has the base hooks and lean-ctx guidance block to harden.
seed_home() {
  local home="$1"
  mkdir -p "$home/bin" "$home/.agents" "$home/.claude"
  ln -s "$NODE_PATH_BIN" "$home/bin/node"

  cat > "$home/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          { "command": "/opt/lean-ctx hook rewrite", "type": "command" }
        ],
        "matcher": "Bash|bash"
      },
      {
        "hooks": [
          { "command": "/opt/lean-ctx hook redirect", "type": "command" }
        ],
        "matcher": "Read|read|Grep|grep|Glob|glob"
      }
    ]
  },
  "permissions": {
    "allow": [
      "mcp__lean-ctx__ctx_read"
    ]
  }
}
JSON

  cat > "$home/.claude/CLAUDE.md" <<'MD'
# Global Claude Code Configuration

<!-- lean-ctx -->
<!-- lean-ctx-claude-v5 -->
## lean-ctx — Context Runtime

When the `ctx_*` MCP tools are listed in this session, prefer them over native equivalents:
- `ctx_read` instead of `Read` / `cat` for exploration (cached, 10 modes, re-reads ~13 tokens)
- `ctx_search` instead of `Grep` / `rg` (compact results)

Native `Read` → `Edit`/`StrReplace` stays fully supported — the edit gate requires a
prior native Read of the same file path. Write, Delete, Glob — use normally.
If no `ctx_*` tools are listed in this session, use the native tools throughout.

Read modes: anchored (edit), full (verbatim).
<!-- /lean-ctx -->
MD
}

# Verify the routing step installs the hook scripts, repoints both PreToolUse
# matchers, allow-lists the ctx_* edit tools, and hardens the CLAUDE.md block.
routing_hardens_fresh_settings_and_claudemd() {
  local home="$tmp/home-routing-fresh"
  local output settings claude_md
  seed_home "$home"
  settings="$home/.claude/settings.json"
  claude_md="$home/.claude/CLAUDE.md"

  output="$(run_routing "$home" 0)"

  assert_contains "$output" "OK Install lean-ctx routing hooks for Claude Code"
  assert_contains "$output" "OK Harden lean-ctx routing in Claude Code settings"
  assert_contains "$output" "OK Harden lean-ctx guidance in"

  assert_exists "$home/.claude/hooks/lean-ctx-rewrite-wrapper.sh"
  assert_exists "$home/.claude/hooks/lean-ctx-redirect-enforce.sh"
  [ -x "$home/.claude/hooks/lean-ctx-rewrite-wrapper.sh" ] || {
    printf 'rewrite wrapper not executable\n' >&2; exit 1; }
  [ -x "$home/.claude/hooks/lean-ctx-redirect-enforce.sh" ] || {
    printf 'redirect enforce not executable\n' >&2; exit 1; }

  "$NODE_PATH_BIN" -e '
const fs = require("fs");
const c = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const home = process.argv[2];
const cmds = c.hooks.PreToolUse.flatMap(b => b.hooks.map(h => h.command));
const wrapper = `bash ${home}/.claude/hooks/lean-ctx-rewrite-wrapper.sh`;
const enforce = `bash ${home}/.claude/hooks/lean-ctx-redirect-enforce.sh`;
if (!cmds.includes(wrapper)) { console.error("missing wrapper command", cmds); process.exit(1); }
if (!cmds.includes(enforce)) { console.error("missing enforce command", cmds); process.exit(2); }
for (const c2 of cmds) { if (c2.includes("lean-ctx hook rewrite") || c2.includes("lean-ctx hook redirect")) { console.error("stale binary hook remains", c2); process.exit(3); } }
const need = ["ctx_compose","ctx_patch","ctx_shell","ctx_glob","ctx_callgraph","ctx_call","ctx_expand"];
for (const n of need) { if (!c.permissions.allow.includes("mcp__lean-ctx__"+n)) { console.error("missing allow", n); process.exit(4); } }
if (!c.permissions.allow.includes("mcp__lean-ctx__ctx_read")) { console.error("dropped pre-existing allow"); process.exit(5); }
' "$settings" "$home"

  assert_contains "$(cat "$claude_md")" "Do NOT use native Read/Grep/Bash"
  assert_contains "$(cat "$claude_md")" "load lean-ctx before exploring code"
  assert_contains "$(cat "$claude_md")" "Native Read → Edit remains a fallback only when a ctx path fails"
  assert_not_contains "$(cat "$claude_md")" "prefer them over native equivalents"
  assert_not_contains "$(cat "$claude_md")" "use the native tools throughout"
  assert_not_contains "$(cat "$claude_md")" "the edit gate requires a"
}

# Verify a second run does not duplicate hook blocks or allow entries.
routing_is_idempotent() {
  local home="$tmp/home-routing-idem"
  local settings
  seed_home "$home"
  settings="$home/.claude/settings.json"

  run_routing "$home" 0 >/dev/null
  run_routing "$home" 0 >/dev/null

  "$NODE_PATH_BIN" -e '
const fs = require("fs");
const c = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const home = process.argv[2];
const wrapper = `bash ${home}/.claude/hooks/lean-ctx-rewrite-wrapper.sh`;
const enforce = `bash ${home}/.claude/hooks/lean-ctx-redirect-enforce.sh`;
const cmds = c.hooks.PreToolUse.flatMap(b => b.hooks.map(h => h.command));
const nWrap = cmds.filter(x => x === wrapper).length;
const nEnf = cmds.filter(x => x === enforce).length;
if (nWrap !== 1) { console.error("wrapper count", nWrap); process.exit(1); }
if (nEnf !== 1) { console.error("enforce count", nEnf); process.exit(2); }
const seen = {};
for (const a of c.permissions.allow) { seen[a] = (seen[a]||0)+1; }
for (const a in seen) { if (seen[a] !== 1) { console.error("dup allow", a, seen[a]); process.exit(3); } }
' "$settings" "$home"
}

# Verify the routing step appends managed hook blocks when LeanCTX setup left no
# rewrite/redirect entries to repoint.
routing_appends_when_hooks_missing() {
  local home="$tmp/home-routing-append"
  local settings
  mkdir -p "$home/bin" "$home/.agents" "$home/.claude"
  ln -s "$NODE_PATH_BIN" "$home/bin/node"
  printf '{}\n' > "$home/.claude/settings.json"
  settings="$home/.claude/settings.json"

  run_routing "$home" 0 >/dev/null

  "$NODE_PATH_BIN" -e '
const fs = require("fs");
const c = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const home = process.argv[2];
const wrapper = `bash ${home}/.claude/hooks/lean-ctx-rewrite-wrapper.sh`;
const enforce = `bash ${home}/.claude/hooks/lean-ctx-redirect-enforce.sh`;
const bash = c.hooks.PreToolUse.find(b => (b.matcher||"").indexOf("Bash") === 0);
const redir = c.hooks.PreToolUse.find(b => (b.matcher||"").indexOf("Read") === 0);
if (!bash || bash.hooks[0].command !== wrapper) { console.error("no bash block"); process.exit(1); }
if (!redir || redir.hooks[0].command !== enforce) { console.error("no redirect block"); process.exit(2); }
if ((redir.matcher||"").indexOf("Glob") === -1) { console.error("redirect matcher missing Glob"); process.exit(3); }
' "$settings" "$home"
}

# Verify dry-run announces the steps but writes nothing.
routing_dry_run_makes_no_changes() {
  local home="$tmp/home-routing-dry"
  local output before_settings before_md
  seed_home "$home"
  before_settings="$(cat "$home/.claude/settings.json")"
  before_md="$(cat "$home/.claude/CLAUDE.md")"

  output="$(run_routing "$home" 1)"

  assert_contains "$output" "Dry run Install lean-ctx routing hooks for Claude Code"
  assert_contains "$output" "Dry run Harden lean-ctx routing in Claude Code settings"
  assert_contains "$output" "Dry run Harden lean-ctx guidance in"
  [ ! -e "$home/.claude/hooks" ] || {
    printf 'dry-run created hooks dir\n' >&2; exit 1; }
  [ "$(cat "$home/.claude/settings.json")" = "$before_settings" ] || {
    printf 'dry-run modified settings.json\n' >&2; exit 1; }
  [ "$(cat "$home/.claude/CLAUDE.md")" = "$before_md" ] || {
    printf 'dry-run modified CLAUDE.md\n' >&2; exit 1; }
}

# Verify the Claude routing step leaves Codex instruction files untouched.
routing_leaves_codex_untouched() {
  local home="$tmp/home-routing-codex"
  seed_home "$home"
  mkdir -p "$home/.codex"
  printf 'codex original\n' > "$home/.codex/AGENTS.md"

  run_routing "$home" 0 >/dev/null

  [ "$(cat "$home/.codex/AGENTS.md")" = "codex original" ] || {
    printf 'routing modified Codex AGENTS.md\n' >&2; exit 1; }
}

routing_hardens_fresh_settings_and_claudemd
routing_is_idempotent
routing_appends_when_hooks_missing
routing_dry_run_makes_no_changes
routing_leaves_codex_untouched

printf 'install-claude-routing.sh: OK\n'
