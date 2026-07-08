#!/usr/bin/env bash
# lean-ctx PreToolUse Bash wrapper (Claude Code, managed by ai-assistant-stack).
# (a) forwards to `lean-ctx hook rewrite` (preserves the compiled-in whitelist:
#     git, gh, npm, rg, ls, find, ... -> `lean-ctx -c`)
# (b) additionally routes cat|grep|sed|head|tail|awk|less through `lean-ctx -c`
#     (the ctx_shell equivalent) so raw bash reads do not bypass lean-ctx.
# Deterministic + idempotent. Preserves all existing rewrite behavior verbatim.
set -euo pipefail

LEAN_CTX_BIN="$(command -v lean-ctx 2>/dev/null || printf '%s' "$HOME/.local/bin/lean-ctx")"

INPUT=$(cat)

TOOL=$(printf '%s' "$INPUT" | grep -oE '"tool_name":"([^"\\]|\\.)*"' | head -1 | sed 's/^"tool_name":"//;s/"$//;s/\\"/"/g;s/\\\\/\\/g')
case "$TOOL" in
  Bash|bash|PowerShell|powershell) ;;
  *) printf '%s' "$INPUT" | "$LEAN_CTX_BIN" hook rewrite; exit $? ;;
esac

CMD=$(printf '%s' "$INPUT" | grep -oE '"command":"([^"\\]|\\.)*"' | head -1 | sed 's/^"command":"//;s/"$//;s/\\"/"/g;s/\\\\/\\/g')

# Extra read-ish prefixes the compiled whitelist misses. Skip when empty or
# already lean-ctx-wrapped (idempotent).
if [ -n "$CMD" ] && ! printf '%s' "$CMD" | grep -qE "^(lean-ctx |$LEAN_CTX_BIN )"; then
  case "$CMD" in
    cat\ *|grep\ *|sed\ *|head\ *|tail\ *|awk\ *|less\ *)
      SHELL_ESC=$(printf '%s' "$CMD" | sed 's/\\/\\\\/g;s/"/\\"/g')
      REWRITE="$LEAN_CTX_BIN -c \"$SHELL_ESC\""
      JSON_CMD=$(printf '%s' "$REWRITE" | sed 's/\\/\\\\/g;s/"/\\"/g')
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":{"command":"%s"}}}' "$JSON_CMD"
      exit 0
      ;;
  esac
fi

# Everything else -> defer to the binary so existing behavior is preserved.
printf '%s' "$INPUT" | "$LEAN_CTX_BIN" hook rewrite
exit $?
