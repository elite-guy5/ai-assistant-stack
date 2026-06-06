#!/usr/bin/env bash
set -euo pipefail

DEFAULT_PROJECT_SCOPE="{{PROJECT_SCOPE}}"
case "$DEFAULT_PROJECT_SCOPE" in
  "{{"*"}}") DEFAULT_PROJECT_SCOPE="$HOME/Documents" ;;
esac

SCOPE="${PROJECT_SCOPE:-$DEFAULT_PROJECT_SCOPE}"
SCOPE_INPUT="$SCOPE"
CLAUDE_TEMPLATE="${CLAUDE_TEMPLATE:-$HOME/.claude/CLAUDE.project-template.md}"
CODEX_TEMPLATE="${CODEX_TEMPLATE:-$HOME/.codex/AGENTS.project-template.md}"
cwd="${1:-$PWD}"
dry_run="${DRY_RUN:-0}"

resolve_dir() {
  (cd -P "$1" 2>/dev/null && pwd)
}

SCOPE="$(resolve_dir "$SCOPE")" || exit 0

case "$cwd/" in
  "$SCOPE_INPUT"/*/) rel="${cwd#"$SCOPE_INPUT"/}" ;;
  "$SCOPE"/*/) rel="${cwd#"$SCOPE"/}" ;;
  *) exit 0 ;;
esac

child="${rel%%/*}"
[ -n "$child" ] || exit 0

case "$child" in
  .*) exit 0 ;;
esac

project="$SCOPE/$child"
[ ! -L "$project" ] || exit 0
[ -d "$project" ] || exit 0
project="$(resolve_dir "$project")" || exit 0

case "$project/" in
  "$SCOPE"/*/) ;;
  *) exit 0 ;;
esac

target_is_safe() {
  local target="$1"
  local parent current

  [ ! -L "$target" ] || return 1
  parent="$(dirname "$target")"
  current="$parent"
  while [ "$current" != "$project" ] && [ "$current" != "/" ] && [ -n "$current" ]; do
    [ ! -L "$current" ] || return 1
    current="$(dirname "$current")"
  done
  return 0
}

copy_if_missing() {
  local template="$1"
  local target="$2"

  [ -f "$template" ] || return 0
  target_is_safe "$target" || return 0
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
