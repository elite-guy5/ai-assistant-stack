#!/usr/bin/env bash
set -euo pipefail

# Locate the repository and create an isolated temporary workspace for this test
# file.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Assert that command output includes an expected substring.
assert_contains() {
  case "$1" in
    *"$2"*) ;;
    *)
      printf 'expected output to contain: %s\noutput was:\n%s\n' "$2" "$1" >&2
      exit 1
      ;;
  esac
}

# Assert that a path exists.
assert_exists() {
  [ -e "$1" ] || {
    printf 'expected path to exist: %s\n' "$1" >&2
    exit 1
  }
}

# Assert that a path does not exist.
assert_not_exists() {
  [ ! -e "$1" ] || {
    printf 'expected path not to exist: %s\n' "$1" >&2
    exit 1
  }
}

# Verify Git template hooks seed Codex instructions into repositories created
# after installation.
git_template_hooks_seed_future_repos() {
  local home="$tmp/home-template"
  local repo="$tmp/future-repo"
  local template_dir
  mkdir -p "$home"

  HOME="$home" bash "$ROOT/scripts/install.sh" --non-interactive --tools codex >/dev/null

  template_dir="$(HOME="$home" git config --global --get init.templateDir)"
  assert_contains "$template_dir" "$home/.agents/git-template"
  HOME="$home" git -c init.defaultBranch=main init --template="$template_dir" "$repo" >/dev/null
  assert_exists "$repo/.git/hooks/post-checkout"

  HOME="$home" "$home/.agents/scripts/seed-project-instructions.sh" --tools codex "$repo"
  assert_exists "$repo/AGENTS.md"
  assert_not_exists "$repo/CLAUDE.md"
}

# Verify current-repo hook installation wraps a custom hook and seeds only the
# selected tool's instruction file.
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

# Verify seeding skips user-owned files and overwrite mode creates a backup.
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

# Verify mixed-tool seeding does not create a second instruction file when
# either supported project instruction file already exists.
seeder_skips_project_when_any_instruction_file_exists() {
  local home="$tmp/home-cross-skip"
  local repo_with_agents="$tmp/cross-skip-agents"
  local repo_with_claude="$tmp/cross-skip-claude"
  mkdir -p "$home"
  HOME="$home" bash "$ROOT/scripts/install.sh" --non-interactive --tools both >/dev/null

  git -c init.defaultBranch=main init "$repo_with_agents" >/dev/null
  printf 'custom agents\n' > "$repo_with_agents/AGENTS.md"
  HOME="$home" "$home/.agents/scripts/seed-project-instructions.sh" --tools both "$repo_with_agents"
  assert_contains "$(cat "$repo_with_agents/AGENTS.md")" "custom agents"
  assert_not_exists "$repo_with_agents/CLAUDE.md"

  git -c init.defaultBranch=main init "$repo_with_claude" >/dev/null
  printf 'custom claude\n' > "$repo_with_claude/CLAUDE.md"
  HOME="$home" "$home/.agents/scripts/seed-project-instructions.sh" --tools both "$repo_with_claude"
  assert_contains "$(cat "$repo_with_claude/CLAUDE.md")" "custom claude"
  assert_not_exists "$repo_with_claude/AGENTS.md"
}

# Verify checksum mismatch handling rejects tampered bootstrap archives.
bootstrap_rejects_tampered_archive() {
  local archive="$tmp/archive.tar.gz"
  printf 'tampered' > "$archive"
  if TOKEN_SAVER_BOOTSTRAP_ARCHIVE="$archive" TOKEN_SAVER_BOOTSTRAP_SHA256="0000" bash "$ROOT/scripts/bootstrap.sh" --dry-run >"$tmp/bootstrap.out" 2>"$tmp/bootstrap.err"; then
    printf 'tampered bootstrap archive unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/bootstrap.err")" "setup archive checksum mismatch"
}

# Verify bootstrap can run from a local archive without requiring a checked-out
# repository.
bootstrap_runs_local_archive_without_required_checkout() {
  local archive="$tmp/bootstrap-local.tar.gz"
  local home="$tmp/home-bootstrap"
  local archive_root="$tmp/ai-assistant-stack-main"
  mkdir -p "$home" "$archive_root"
  cp -R "$ROOT/scripts" "$archive_root/scripts"
  cp -R "$ROOT/templates" "$archive_root/templates"
  tar -czf "$archive" -C "$tmp" ai-assistant-stack-main

  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  chmod +x "$home/bin/codex"

  HOME="$home" PATH="$home/bin:$PATH" CONTEXT7_API_KEY=test-key TOKEN_SAVER_BOOTSTRAP_ARCHIVE="$archive" \
    bash "$ROOT/scripts/bootstrap.sh" --non-interactive --targets codex-desktop --dry-run >"$tmp/bootstrap-local.out"

  assert_contains "$(cat "$tmp/bootstrap-local.out")" "Selected targets"
  assert_contains "$(cat "$tmp/bootstrap-local.out")" "OK Codex Desktop"
  assert_contains "$(cat "$tmp/bootstrap-local.out")" "Selected tools"
  assert_contains "$(cat "$tmp/bootstrap-local.out")" "OK codex"
  assert_contains "$(cat "$tmp/bootstrap-local.out")" "Install complete"
}

# Verify bootstrap still prompts correctly when the script itself is piped into
# bash and stdin would otherwise be exhausted.
bootstrap_runs_when_script_is_piped_to_bash() {
  local archive="$tmp/bootstrap-piped.tar.gz"
  local home="$tmp/home-bootstrap-piped"
  local archive_root="$tmp/ai-assistant-stack-piped"
  mkdir -p "$home/bin" "$archive_root"
  cp -R "$ROOT/scripts" "$archive_root/scripts"
  cp -R "$ROOT/templates" "$archive_root/templates"
  tar -czf "$archive" -C "$tmp" ai-assistant-stack-piped

  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/code"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/claude"
  chmod +x "$home/bin/codex" "$home/bin/code" "$home/bin/claude"

  HOME="$home" PATH="$home/bin:$PATH" CONTEXT7_API_KEY=test-key TOKEN_SAVER_BOOTSTRAP_ARCHIVE="$archive" TOKEN_SAVER_TEST_KEYS=$' j j j \n' \
    bash -s -- --overwrite --dry-run < "$ROOT/scripts/bootstrap.sh" >"$tmp/bootstrap-piped.out"

  assert_contains "$(cat "$tmp/bootstrap-piped.out")" "Select targets to configure"
  assert_contains "$(cat "$tmp/bootstrap-piped.out")" "OK Codex Desktop"
  assert_contains "$(cat "$tmp/bootstrap-piped.out")" "OK Codex VS Code"
  assert_contains "$(cat "$tmp/bootstrap-piped.out")" "OK Claude Code CLI"
  assert_contains "$(cat "$tmp/bootstrap-piped.out")" "OK Claude Code VS Code"
  assert_contains "$(cat "$tmp/bootstrap-piped.out")" "Selected tools"
  assert_contains "$(cat "$tmp/bootstrap-piped.out")" "OK both"
  assert_contains "$(cat "$tmp/bootstrap-piped.out")" "Install complete"
}

# Run hook, seeding, and bootstrap security regression scenarios.
git_template_hooks_seed_future_repos
current_repo_hook_wraps_existing_hook_and_seeds_selected_files
seeder_skips_existing_files_and_overwrite_creates_backup
seeder_skips_project_when_any_instruction_file_exists
bootstrap_rejects_tampered_archive
bootstrap_runs_local_archive_without_required_checkout
bootstrap_runs_when_script_is_piped_to_bash

printf 'security-regression.sh: OK\n'
