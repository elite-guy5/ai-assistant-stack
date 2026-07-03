#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

r1="ru"
r2="flo"
agent="agent"
db="db"
vector="vector"
claude="claude"
flow="flow"
dot="."

pattern="${r1}${r2}|\\${dot}${r1}${r2}|${agent}${db}|${r1}${vector}|${claude}-${flow}|\\${dot}swarm|${r1}${r2}@"

if git ls-files -z --cached --others --exclude-standard |
  while IFS= read -r -d '' file; do
    [ -e "$file" ] && printf '%s\0' "$file"
  done |
  xargs -0 rg -n -i "$pattern"; then
  printf 'Removed setup/runtime references remain in repository files.\n' >&2
  exit 1
fi

printf 'removed-stack-scan.sh: OK\n'
