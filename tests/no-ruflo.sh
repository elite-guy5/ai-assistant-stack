#!/usr/bin/env bash
set -euo pipefail

# Run the repository scan from the project root so tracked and untracked file
# paths are resolved consistently.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

# Assemble the forbidden-reference pattern from fragments so the test does not
# match its own search terms.
r1="ru"
r2="flo"
agent="agent"
db="db"
vector="vector"
claude="claude"
flow="flow"
dot="."

pattern="${r1}${r2}|\\${dot}${r1}${r2}|${agent}${db}|${r1}${vector}|${claude}-${flow}|\\${dot}swarm|${r1}${r2}@"

# Search all non-ignored repository files and fail if removed stack/runtime
# references are still present.
if git ls-files -z --cached --others --exclude-standard |
  while IFS= read -r -d '' file; do
    [ -e "$file" ] && printf '%s\0' "$file"
  done |
  xargs -0 rg -n -i "$pattern"; then
  printf 'Removed setup/runtime references remain in repository files.\n' >&2
  exit 1
fi

printf 'removed-stack-scan.sh: OK\n'
