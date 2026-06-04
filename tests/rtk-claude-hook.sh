#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export PATH="$tmp/bin:$PATH"
mkdir -p "$tmp/bin"

cat > "$tmp/bin/rtk" <<'SH'
#!/usr/bin/env bash
set -eu
printf 'MANUAL STEP: Add this to ~/.claude/settings.json:\n'
if [ "${1:-}" = "--version" ]; then
  printf 'rtk-test\n'
  exit 0
fi
if [ "${1:-}" = "init" ]; then
  mkdir -p "$HOME/.claude" "$HOME/.codex"
  printf '# Claude\n@RTK.md\n' > "$HOME/.claude/CLAUDE.md"
  printf 'Hook-Based Usage\n' > "$HOME/.claude/RTK.md"
  printf '# Codex\n@RTK.md\n' > "$HOME/.codex/AGENTS.md"
  printf 'Always prefix shell commands with `rtk`\n' > "$HOME/.codex/RTK.md"
fi
exit 0
SH
chmod +x "$tmp/bin/rtk"

run_install() {
  local home="$1"
  HOME="$home" TOKEN_SAVER_MANIFEST="$home/.agents/install_manifest.json" \
    bash "$ROOT/scripts/install.sh" --non-interactive --skip-caveman --rtk-agents claude --rtk-mode manual
}

assert_hook_state() {
  local settings="$1"
  local expected_count="${2:-1}"
  node - "$settings" "$expected_count" <<'NODE'
const fs = require("fs");
const [settingsPath, expectedRaw] = process.argv.slice(2);
const expected = Number(expectedRaw);
const data = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
if (data.theme && data.theme !== "dark") throw new Error("unrelated key changed");
const preToolUse = data.hooks && Array.isArray(data.hooks.PreToolUse) ? data.hooks.PreToolUse : [];
let count = 0;
for (const entry of preToolUse) {
  for (const hook of Array.isArray(entry.hooks) ? entry.hooks : []) {
    if (hook && hook.type === "command" && hook.command === "rtk hook claude") count++;
  }
}
if (count !== expected) throw new Error(`expected ${expected} RTK hook(s), found ${count}`);
NODE
}

assert_manifest_action() {
  local manifest="$1"
  local expected="$2"
  node - "$manifest" "$expected" <<'NODE'
const fs = require("fs");
const [manifestPath, expected] = process.argv.slice(2);
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const artifact = (manifest.artifacts || []).find((item) =>
  item.type === "settings_entry" &&
  item.component === "rtk" &&
  item.path.endsWith("/.claude/settings.json") &&
  item.details &&
  item.details.key === "hooks.PreToolUse" &&
  item.details.command === "rtk hook claude" &&
  item.details.managedEntry === "RTK Claude hook" &&
  item.details.uninstallBehavior === "remove only the RTK hook entry, preserve the file"
);
if (!artifact) throw new Error("RTK settings manifest artifact missing");
if (artifact.action !== expected) throw new Error(`expected manifest action ${expected}, got ${artifact.action}`);
NODE
}

install_case() {
  local name="$1"
  local json="${2:-}"
  local expected_action="${3:-added}"
  local home="$tmp/$name/home"
  local had_settings=0
  mkdir -p "$home/.claude"
  if [ "$json" != "__missing__" ]; then
    printf '%s\n' "$json" > "$home/.claude/settings.json"
    had_settings=1
  fi

  output="$(run_install "$home")"
  if ! printf '%s\n' "$output" | grep -Fq 'MANUAL STEP'; then
    printf '%s did not print RTK child installer output\n' "$name" >&2
    exit 1
  fi
  assert_hook_state "$home/.claude/settings.json" 1
  if [ "$had_settings" = "1" ]; then
    test -f "$home/.claude/settings.json.bak"
  fi
  assert_manifest_action "$home/.agents/install_manifest.json" "$expected_action"
}

install_case missing "__missing__"
install_case empty_object '{}'
install_case unrelated_keys '{"theme":"dark"}'
install_case hooks_no_pretooluse '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"echo seed"}]}]}}'
install_case pretooluse_no_bash '{"hooks":{"PreToolUse":[{"matcher":"Edit","hooks":[{"type":"command","command":"echo edit"}]}]}}'
install_case bash_unrelated '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"echo existing"}]}]}}'
install_case already_present '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"rtk hook claude"}]}]}}' already_existed

invalid_home="$tmp/invalid/home"
mkdir -p "$invalid_home/.claude"
printf '{ invalid json\n' > "$invalid_home/.claude/settings.json"
if run_install "$invalid_home" > "$tmp/invalid-output.txt" 2>&1; then
  printf 'invalid JSON install unexpectedly succeeded\n' >&2
  exit 1
fi
test -f "$invalid_home/.claude/settings.json.bak"
grep -Fq 'invalid JSON' "$tmp/invalid-output.txt"

uninstall_home="$tmp/uninstall/home"
mkdir -p "$uninstall_home/.claude"
cat > "$uninstall_home/.claude/settings.json" <<'JSON'
{
  "theme": "dark",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "echo existing" },
          { "type": "command", "command": "rtk hook claude" }
        ]
      },
      {
        "matcher": "Edit",
        "hooks": [
          { "type": "command", "command": "echo edit" }
        ]
      }
    ]
  }
}
JSON
run_install "$uninstall_home" >/dev/null
HOME="$uninstall_home" TOKEN_SAVER_MANIFEST="$uninstall_home/.agents/install_manifest.json" \
  bash "$ROOT/scripts/install.sh" --non-interactive --dry-run --uninstall --uninstall-components rtk >/dev/null
HOME="$uninstall_home" TOKEN_SAVER_MANIFEST="$uninstall_home/.agents/install_manifest.json" \
  bash "$ROOT/scripts/install.sh" --non-interactive --uninstall --uninstall-components rtk >/dev/null
test -f "$uninstall_home/.claude/settings.json"
assert_hook_state "$uninstall_home/.claude/settings.json" 0
grep -Fq 'echo existing' "$uninstall_home/.claude/settings.json"
grep -Fq 'echo edit' "$uninstall_home/.claude/settings.json"
grep -Fq '"theme": "dark"' "$uninstall_home/.claude/settings.json"

printf 'rtk-claude-hook.sh: OK\n'
