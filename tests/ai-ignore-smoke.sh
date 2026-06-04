#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export PROJECT_SCOPE="$tmp/projects"
export CLAUDE_TEMPLATE="$tmp/templates/CLAUDE.md"
export CODEX_TEMPLATE="$tmp/templates/AGENTS.md"

project="$PROJECT_SCOPE/example"
mkdir -p "$project" "$(dirname "$CLAUDE_TEMPLATE")" "$(dirname "$CODEX_TEMPLATE")"
printf '# Claude\n' > "$CLAUDE_TEMPLATE"
printf '# Codex\n' > "$CODEX_TEMPLATE"

bash "$ROOT/scripts/seed-project-instructions.sh" "$project/src"

test -f "$project/CLAUDE.md"
test -f "$project/AGENTS.md"
test -f "$project/.gitignore"
test -f "$project/.codexignore"
test -f "$project/.claude/settings.local.json"

grep -Fq 'node_modules/' "$project/.gitignore"
grep -Fq '.env.*' "$project/.gitignore"
grep -Fq 'package-lock.json' "$project/.codexignore"
grep -Fq 'Read(./.env.*)' "$project/.claude/settings.local.json"
grep -Fq 'Read(./node_modules/**)' "$project/.claude/settings.local.json"
