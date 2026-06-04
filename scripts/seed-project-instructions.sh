#!/usr/bin/env bash
set -euo pipefail

DEFAULT_PROJECT_SCOPE="{{PROJECT_SCOPE}}"
case "$DEFAULT_PROJECT_SCOPE" in
  "{{"*"}}") DEFAULT_PROJECT_SCOPE="$HOME/Documents/git" ;;
esac

SCOPE="${PROJECT_SCOPE:-$DEFAULT_PROJECT_SCOPE}"
CLAUDE_TEMPLATE="${CLAUDE_TEMPLATE:-$HOME/.claude/CLAUDE.project-template.md}"
CODEX_TEMPLATE="${CODEX_TEMPLATE:-$HOME/.codex/AGENTS.project-template.md}"
cwd="${1:-$PWD}"
dry_run="${DRY_RUN:-0}"

case "$cwd/" in
  "$SCOPE"/*/) ;;
  *) exit 0 ;;
esac

rel="${cwd#"$SCOPE"/}"
child="${rel%%/*}"
[ -n "$child" ] || exit 0

case "$child" in
  .*) exit 0 ;;
esac

project="$SCOPE/$child"
[ -d "$project" ] || exit 0

copy_if_missing() {
  local template="$1"
  local target="$2"

  [ -f "$template" ] || return 0
  [ ! -e "$target" ] || return 0

  if [ "$dry_run" = "1" ]; then
    printf 'would create %s from %s\n' "$target" "$template"
    return 0
  fi

  cp "$template" "$target"
}

copy_if_missing "$CLAUDE_TEMPLATE" "$project/CLAUDE.md"
copy_if_missing "$CODEX_TEMPLATE" "$project/AGENTS.md"

optimizer="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/optimize-ai.sh"
if [ -f "$optimizer" ]; then
  bash "$optimizer" "$project"
fi
