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

context7_credentials_required() {
  local home="$tmp/home-context7"
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  chmod +x "$home/bin/codex"

  if HOME="$home" PATH="$home/bin:$PATH" \
    bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets codex-desktop >"$tmp/context7.out" 2>"$tmp/context7.err"; then
    printf 'missing Context7 credentials unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/context7.err")" "Context7 credentials are required before stack configuration."
  assert_contains "$(cat "$tmp/context7.err")" "export CONTEXT7_API_KEY=\"your-context7-api-key\""
}

dry_run_prints_stack_steps_for_codex() {
  local home="$tmp/home-stack-codex"
  local output
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  chmod +x "$home/bin/codex"

  output="$(
    HOME="$home" PATH="$home/bin:$PATH" CONTEXT7_API_KEY=test-key \
      bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets codex-desktop
  )"

  assert_contains "$output" "Step: Install LeanCTX"
  assert_contains "$output" "Step: Configure Context7"
  assert_contains "$output" "Step: Configure Ruflo"
  assert_contains "$output" "Step: Install Caveman"
  assert_contains "$output" "Step: Install Superpowers"
  assert_contains "$output" "codex mcp add context7"
  assert_contains "$output" "--api-key <redacted>"
}

ruflo_project_state_is_reported
context7_credentials_required
dry_run_prints_stack_steps_for_codex

printf 'install-stack-tools.sh: OK\n'
