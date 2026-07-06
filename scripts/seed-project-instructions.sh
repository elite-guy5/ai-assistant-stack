#!/usr/bin/env bash
set -euo pipefail

# Default to seeding both instruction-file types unless the hook or caller
# restricts the tool scope.
tools="${TOKEN_SAVER_TOOLS:-both}"
overwrite=0
cwd="$PWD"

# Print an error and stop the seeder.
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

# Normalize tool aliases to the canonical seeding selector.
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

# Return success when the canonical selector includes the requested tool.
tool_enabled() {
  case "$tools:$1" in
    both:*|codex:codex|claude:claude) return 0 ;;
    *) return 1 ;;
  esac
}

# Build a timestamped backup filename for overwrite mode.
backup_path() {
  local path="$1"
  printf '%s.token-saver-backup-%s' "$path" "$(date +%Y%m%d%H%M%S)"
}

# Copy one project instruction template when available, preserving existing files
# unless overwrite mode is active.
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

append_token_saver_boundaries() {
  local template="$1"
  local target="$2"
  local section

  [ -f "$template" ] || return 0
  [ -f "$target" ] || return 0
  [ ! -L "$target" ] || return 0
  ! grep -Fq '## Token-Saver File Boundaries' "$target" || return 0

  section="$(
    awk '
      /^## Token-Saver File Boundaries$/ { in_section = 1 }
      in_section { print }
      in_section && /^---$/ { exit }
    ' "$template"
  )"
  [ -n "$section" ] || return 0

  {
    printf '\n---\n\n'
    printf '%s\n' "$section"
  } >> "$target"
}

# Detect either supported project instruction file so mixed-tool installs avoid
# writing around user-owned configuration.
project_instruction_file_exists() {
  [ -e "$repo_root/AGENTS.md" ] || [ -e "$repo_root/CLAUDE.md" ]
}

# Parse the seeder's small option set before resolving the repository root.
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

# Resolve the target Git repository and skip non-repositories or symlink roots.
tools="$(normalize_tools "$tools")"
repo_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$repo_root" ] || exit 0
[ ! -L "$repo_root" ] || exit 0

# Preserve existing project instruction files unless the caller explicitly
# requested overwrite.
if [ "$overwrite" = "0" ] && project_instruction_file_exists; then
  if tool_enabled codex; then
    append_token_saver_boundaries "$HOME/.codex/AGENTS.project-template.md" "$repo_root/AGENTS.md"
  fi

  if tool_enabled claude; then
    append_token_saver_boundaries "$HOME/.claude/CLAUDE.project-template.md" "$repo_root/CLAUDE.md"
  fi

  exit 0
fi

# Seed the Codex and Claude project files selected by the tool scope.
if tool_enabled codex; then
  copy_instruction_file "$HOME/.codex/AGENTS.project-template.md" "$repo_root/AGENTS.md"
fi

if tool_enabled claude; then
  copy_instruction_file "$HOME/.claude/CLAUDE.project-template.md" "$repo_root/CLAUDE.md"
fi
