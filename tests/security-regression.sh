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

assert_exists() {
  [ -e "$1" ] || {
    printf 'expected path to exist: %s\n' "$1" >&2
    exit 1
  }
}

assert_not_exists() {
  [ ! -e "$1" ] || {
    printf 'expected path not to exist: %s\n' "$1" >&2
    exit 1
  }
}

git_template_hooks_seed_future_repos() {
  local home="$tmp/home-template"
  local repo="$tmp/future-repo"
  mkdir -p "$home"

  HOME="$home" bash "$ROOT/scripts/install.sh" --non-interactive --tools codex >/dev/null

  HOME="$home" git -c init.defaultBranch=main init "$repo" >/dev/null
  assert_exists "$repo/.git/hooks/post-checkout"

  HOME="$home" "$home/.agents/scripts/seed-project-instructions.sh" --tools codex "$repo"
  assert_exists "$repo/AGENTS.md"
  assert_not_exists "$repo/CLAUDE.md"
}

current_repo_hook_wraps_existing_hook_and_seeds_selected_files() {
  local home="$tmp/home-current"
  local repo="$tmp/current-repo"
  local hook
  mkdir -p "$home"
  git -c init.defaultBranch=main init "$repo" >/dev/null
  hook="$repo/.git/hooks/post-checkout"
  printf '#!/usr/bin/env bash\nprintf custom-hook\\n\n' > "$hook"
  chmod +x "$hook"

  HOME="$home" bash "$ROOT/scripts/install.sh" --non-interactive --tools claude --repo "$repo" >/dev/null

  assert_exists "$repo/CLAUDE.md"
  assert_not_exists "$repo/AGENTS.md"
  assert_contains "$(cat "$hook")" "TOKEN_SAVER_MANAGED_HOOK_BEGIN"
  assert_contains "$(cat "$hook")" ".token-saver-backup"

  HOME="$home" bash "$ROOT/scripts/install.sh" --non-interactive --uninstall >/dev/null
  assert_contains "$(cat "$hook")" "custom-hook"
}

seeder_skips_existing_files_and_overwrite_creates_backup() {
  local home="$tmp/home-overwrite"
  local repo="$tmp/overwrite-repo"
  mkdir -p "$home"
  HOME="$home" bash "$ROOT/scripts/install.sh" --non-interactive --tools codex >/dev/null
  git -c init.defaultBranch=main init "$repo" >/dev/null
  printf 'custom\n' > "$repo/AGENTS.md"

  HOME="$home" "$home/.agents/scripts/seed-project-instructions.sh" --tools codex "$repo"
  assert_contains "$(cat "$repo/AGENTS.md")" "custom"

  HOME="$home" "$home/.agents/scripts/seed-project-instructions.sh" --tools codex --overwrite "$repo"
  assert_contains "$(cat "$repo/AGENTS.md")" "Project AGENTS.md"
  ls "$repo"/AGENTS.md.token-saver-backup-* >/dev/null
}

bootstrap_rejects_tampered_archive() {
  local archive="$tmp/archive.tar.gz"
  printf 'tampered' > "$archive"
  if TOKEN_SAVER_BOOTSTRAP_ARCHIVE="$archive" TOKEN_SAVER_BOOTSTRAP_SHA256="0000" bash "$ROOT/scripts/bootstrap.sh" --dry-run >"$tmp/bootstrap.out" 2>"$tmp/bootstrap.err"; then
    printf 'tampered bootstrap archive unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/bootstrap.err")" "setup archive checksum mismatch"
}

git_template_hooks_seed_future_repos
current_repo_hook_wraps_existing_hook_and_seeds_selected_files
seeder_skips_existing_files_and_overwrite_creates_backup
bootstrap_rejects_tampered_archive

printf 'security-regression.sh: OK\n'
