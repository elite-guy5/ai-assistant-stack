#!/usr/bin/env bash
# lean-ctx PreToolUse enforce hook (Claude Code, managed by ai-assistant-stack).
# Nudges native Read/Grep/Glob/View/Search on source files toward ctx_* tools.
#   decision "ask"   -> source-looking paths (soft gate; keeps an escape hatch)
#   decision "allow" -> excluded paths (lockfiles/builds/.env/binaries/>100 KB)
# NOTE: a PreToolUse hook is stateless and never sees mcp__lean-ctx__ctx_* calls
#   (they don't match this matcher), so "allow native Read only when the prior
#   call for this path was ctx_*" is not feasible here. We default to "ask",
#   which preserves the transition escape hatch (approve to fall through).
# Deterministic, idempotent (no state mutation), fast (no network).
set -euo pipefail

INPUT=$(cat)

json_get() {
  { printf '%s' "$INPUT" | grep -oE "\"$1\":\"([^\"\\\\]|\\\\.)*\"" | head -1 \
    | sed "s/^\"$1\":\"//;s/\"$//;s/\\\\\"/\"/g;s/\\\\\\\\/\\\\/g"; } || true
}

allow() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
  exit 0
}
ask() {
  R=$(printf '%s' "$1" | sed 's/\\/\\\\/g;s/"/\\"/g')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}' "$R"
  exit 0
}

TOOL=$(json_get tool_name)
FILE=$(json_get file_path)
if [ -z "$FILE" ]; then FILE=$(json_get path); fi

# No concrete path (e.g. Grep/Glob over the tree) -> nudge to ctx search/tree.
if [ -z "$FILE" ]; then
  ask "Use ctx_search / ctx_tree / ctx_glob instead of native $TOOL. Approve only if a ctx_* call already failed."
fi

# Excluded set -> pass through (Token-Saver / deny rules already govern these).
case "$FILE" in
  *.env|*.env.*|\
  */node_modules/*|*/vendor/*|*/.venv/*|*/venv/*|*/dist/*|*/build/*|*/out/*|\
  */.next/*|*/.nuxt/*|*/target/*|*/coverage/*|*/.git/*|\
  *package-lock.json|*pnpm-lock.yaml|*yarn.lock|*poetry.lock|*Cargo.lock|\
  *Gemfile.lock|*composer.lock|*go.sum|\
  *.png|*.jpg|*.jpeg|*.gif|*.ico|*.pdf|*.zip|*.tar|*.gz|*.tgz|*.bz2|*.7z|\
  *.woff|*.woff2|*.ttf|*.eot|*.mp4|*.mov|*.mp3|*.wav|\
  *.exe|*.dll|*.so|*.dylib|*.bin|*.wasm|*.jar|*.class|*.o|*.a|*.lib|\
  *.db|*.sqlite|*.sqlite3|*.log)
    allow
    ;;
esac

# Large files -> skip per the 100 KB Token-Saver rule.
if [ -f "$FILE" ]; then
  SZ=$(wc -c < "$FILE" 2>/dev/null | tr -d ' ')
  if [ -n "$SZ" ] && [ "$SZ" -gt 102400 ]; then
    allow
  fi
fi

# Source-looking file -> soft gate toward ctx_read.
ask "Use ctx_read (mode=anchored for edits) instead of native $TOOL on $FILE. Approve only if a ctx_* call already failed."
