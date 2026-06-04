#!/usr/bin/env bash
set -euo pipefail

project="${1:-$PWD}"
dry_run="${DRY_RUN:-0}"

gitignore_block='# -- AI Token Bloat Exclusions --
.env
.env.*
*.log
logs/
coverage/
.nyc_output/
dist/
build/
out/
.next/
.nuxt/
node_modules/
vendor/
.venv/
venv/
__pycache__/
package-lock.json
pnpm-lock.yaml
yarn.lock
poetry.lock
*.db
*.sqlite
*.sqlite3
# -- End AI Token Bloat Exclusions --
'

codex_extra_block='# -- AI-Only Binary and Asset Exclusions --
*.png
*.jpg
*.jpeg
*.gif
*.webp
*.ico
*.pdf
*.zip
*.tar
*.tgz
*.gz
*.7z
*.dmg
*.mp4
*.mov
*.mp3
*.wav
# -- End AI-Only Binary and Asset Exclusions --
'

claude_settings='{
  "permissions": {
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./package-lock.json)",
      "Read(./pnpm-lock.yaml)",
      "Read(./yarn.lock)",
      "Read(./poetry.lock)",
      "Read(./node_modules/**)",
      "Read(./vendor/**)",
      "Read(./.venv/**)",
      "Read(./venv/**)",
      "Read(./dist/**)",
      "Read(./build/**)",
      "Read(./out/**)",
      "Read(./.next/**)",
      "Read(./.nuxt/**)",
      "Read(./coverage/**)",
      "Read(./.nyc_output/**)",
      "Read(./**/*.log)",
      "Read(./**/*.db)",
      "Read(./**/*.sqlite)",
      "Read(./**/*.sqlite3)"
    ]
  }
}
'

render_without_block() {
  local file="$1"
  local start="$2"
  local end="$3"
  if [ -f "$file" ]; then
    awk -v start="$start" -v end="$end" '
      $0 == start { skipping = 1; next }
      $0 == end { skipping = 0; next }
      !skipping { print }
    ' "$file"
  fi
}

copy_or_new() {
  local source="$1"
  local target="$2"

  if [ "$dry_run" = "1" ]; then
    if [ ! -e "$target" ]; then
      printf 'dry-run: would create %s\n' "$target"
    elif cmp -s "$source" "$target"; then
      printf 'dry-run: already current %s\n' "$target"
    else
      printf 'dry-run: would skip existing %s\n' "$target"
    fi
    return 0
  fi

  mkdir -p "$(dirname "$target")"
  if [ ! -e "$target" ]; then
    cp "$source" "$target"
    printf 'created %s\n' "$target"
    return 0
  fi
  if cmp -s "$source" "$target"; then
    printf 'already current %s\n' "$target"
    return 0
  fi
  printf 'skipped existing %s\n' "$target"
}

main() {
  [ -d "$project" ] || exit 0

  local temp_gitignore temp_codex temp_claude
  temp_gitignore="$(mktemp)"
  render_without_block "$project/.gitignore" \
    "# -- AI Token Bloat Exclusions --" \
    "# -- End AI Token Bloat Exclusions --" > "$temp_gitignore"
  printf '%s\n' "$gitignore_block" >> "$temp_gitignore"
  copy_or_new "$temp_gitignore" "$project/.gitignore"

  temp_codex="$(mktemp)"
  cat "$temp_gitignore" > "$temp_codex"
  printf '%s\n' "$codex_extra_block" >> "$temp_codex"
  copy_or_new "$temp_codex" "$project/.codexignore"
  rm -f "$temp_gitignore"
  rm -f "$temp_codex"

  temp_claude="$(mktemp)"
  printf '%s' "$claude_settings" > "$temp_claude"
  copy_or_new "$temp_claude" "$project/.claude/settings.local.json"
  rm -f "$temp_claude"
}

main
