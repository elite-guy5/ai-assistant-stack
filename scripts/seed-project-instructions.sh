#!/usr/bin/env bash
set -euo pipefail

tools="${TOKEN_SAVER_TOOLS:-both}"
overwrite=0
cwd="$PWD"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

normalize_tools() {
  local value="$1"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
  case "$value" in
    codex|agent|agents) printf 'codex' ;;
    claude|claude-code|claudecode) printf 'claude' ;;
    both|all|codex,claude|claude,codex) printf 'both' ;;
    *) die "invalid --tools value: $1" ;;
  esac
}

tool_enabled() {
  case "$tools:$1" in
    both:*|codex:codex|claude:claude) return 0 ;;
    *) return 1 ;;
  esac
}

backup_path() {
  local path="$1"
  printf '%s.token-saver-backup-%s' "$path" "$(date +%Y%m%d%H%M%S)"
}

copy_instruction_file() {
  local template="$1"
  local target="$2"
  local backup

  [ -f "$template" ] || return 0
  [ ! -L "$target" ] || return 0

  if [ -e "$target" ]; then
    if [ "$overwrite" = "1" ]; then
      backup="$(backup_path "$target")"
      cp "$target" "$backup"
    else
      return 0
    fi
  fi

  cp "$template" "$target"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --tools)
      [ "$#" -gt 1 ] || die "missing value for --tools"
      tools="$(normalize_tools "$2")"
      shift
      ;;
    --tools=*) tools="$(normalize_tools "${1#*=}")" ;;
    --overwrite) overwrite=1 ;;
    --help|-h)
      printf 'Usage: seed-project-instructions.sh [--tools codex|claude|both] [--overwrite] [path]\n'
      exit 0
      ;;
    --*) die "unknown option: $1" ;;
    *) cwd="$1" ;;
  esac
  shift
done

tools="$(normalize_tools "$tools")"
repo_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$repo_root" ] || exit 0
[ ! -L "$repo_root" ] || exit 0

if tool_enabled codex; then
  copy_instruction_file "$HOME/.codex/AGENTS.project-template.md" "$repo_root/AGENTS.md"
fi

if tool_enabled claude; then
  copy_instruction_file "$HOME/.claude/CLAUDE.project-template.md" "$repo_root/CLAUDE.md"
fi
