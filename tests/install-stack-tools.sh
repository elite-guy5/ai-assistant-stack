#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_contains() {
  case "$1" in
    *"$2"*) ;;
    *)
      printf 'expected output to contain: %s\noutput was:\n%s\n' "$2" "$1" >&2
      exit 1
      ;;
  esac
}

ruflo_project_state_is_reported() {
  local home="$tmp/home-ruflo"
  local repo="$tmp/repo-ruflo"
  local output
  mkdir -p "$home/bin" "$repo/.ruflo"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  chmod +x "$home/bin/codex"

  output="$(
    cd "$repo"
    HOME="$home" PATH="$home/bin:$PATH" CONTEXT7_API_KEY=test-key \
      bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets codex-desktop
  )"

  assert_contains "$output" "Warning: project-local Ruflo state path found: $repo/.ruflo"
  assert_contains "$output" "Ruflo runtime state root: $home/.ruflo"
}

ruflo_project_state_is_reported

printf 'install-stack-tools.sh: OK\n'
