#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_not_contains() {
  local haystack="$1"
  local needle="$2"

  if printf '%s\n' "$haystack" | grep -Fq "$needle"; then
    printf 'unexpected output contained: %s\n' "$needle" >&2
    exit 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if ! printf '%s\n' "$haystack" | grep -Fq "$needle"; then
    printf 'expected output to contain: %s\n' "$needle" >&2
    exit 1
  fi
}

stub_command() {
  local name="$1"
  printf '#!/usr/bin/env sh\nexit 0\n' > "$tmp/bin/$name"
  chmod +x "$tmp/bin/$name"
}

bootstrap_rejects_tampered_archive() {
  local archive script output status

  mkdir -p "$tmp/bootstrap/token-saver-setup-main/scripts"
  cat > "$tmp/bootstrap/token-saver-setup-main/scripts/install.sh" <<'SH'
#!/usr/bin/env bash
printf 'unexpected install execution\n'
exit 0
SH
  chmod +x "$tmp/bootstrap/token-saver-setup-main/scripts/install.sh"
  archive="$tmp/tampered.tar.gz"
  tar -czf "$archive" -C "$tmp/bootstrap" token-saver-setup-main

  script="$tmp/bootstrap.sh"
  sed "s|^ARCHIVE_URL=.*|ARCHIVE_URL=\"file://$archive\"|" "$ROOT/scripts/bootstrap.sh" > "$script"
  chmod +x "$script"

  set +e
  output="$(bash "$script" 2>&1)"
  status=$?
  set -e

  if [ "$status" = "0" ]; then
    printf 'tampered bootstrap archive was accepted\n' >&2
    printf '%s\n' "$output" >&2
    exit 1
  fi
  assert_contains "$output" "checksum"
  assert_not_contains "$output" "unexpected install execution"
}

install_defaults_skip_unverified_remote_commands() {
  local output

  mkdir -p "$tmp/bin" "$tmp/home"
  export HOME="$tmp/home"
  export PATH="$tmp/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  stub_command claude
  stub_command codex
  stub_command gemini
  stub_command cursor
  stub_command npx

  output="$(bash "$ROOT/scripts/install.sh" --dry-run --non-interactive)"
  assert_not_contains "$output" "curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh"
  assert_not_contains "$output" "claude plugin marketplace add JuliusBrussee/caveman"
  assert_not_contains "$output" "claude plugin install caveman@caveman"
  assert_not_contains "$output" "npx skills add JuliusBrussee/caveman"
  assert_contains "$output" "skipping unverified"

  output="$(bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --allow-unverified-downloads)"
  assert_contains "$output" "curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh"
  assert_contains "$output" "claude plugin marketplace add JuliusBrussee/caveman"
  assert_contains "$output" "npx skills add JuliusBrussee/caveman -a codex --yes --global"
}

powershell_defaults_skip_unverified_remote_commands() {
  command -v pwsh >/dev/null 2>&1 || return 0

  local output
  mkdir -p "$tmp/ps-bin" "$tmp/ps-home"
  export HOME="$tmp/ps-home"
  export TOKEN_SAVER_HOME="$tmp/ps-home"
  export PATH="$tmp/ps-bin:/usr/bin:/bin:/usr/sbin:/sbin"
  stub_command claude
  stub_command codex
  stub_command gemini
  stub_command cursor
  stub_command npx

  output="$(pwsh -NoProfile -File "$ROOT/scripts/install.ps1" -DryRun -NonInteractive)"
  assert_not_contains "$output" "latest rtk-x86_64-pc-windows-msvc.zip release asset"
  assert_not_contains "$output" "claude plugin marketplace add JuliusBrussee/caveman"
  assert_not_contains "$output" "npx skills add JuliusBrussee/caveman"
  assert_contains "$output" "skipping unverified"

  output="$(pwsh -NoProfile -File "$ROOT/scripts/install.ps1" -DryRun -NonInteractive -AllowUnverifiedDownloads)"
  assert_contains "$output" "latest rtk-x86_64-pc-windows-msvc.zip release asset"
  assert_contains "$output" "claude plugin marketplace add JuliusBrussee/caveman"
  assert_contains "$output" "npx skills add JuliusBrussee/caveman -a codex --yes --global"
}

seed_rejects_symlinked_project_root() {
  local scope outside templates

  scope="$tmp/projects"
  outside="$tmp/outside"
  templates="$tmp/templates"
  mkdir -p "$scope" "$outside" "$templates"
  ln -s "$outside" "$scope/example"
  printf '# Claude\n' > "$templates/CLAUDE.md"
  printf '# Codex\n' > "$templates/AGENTS.md"

  PROJECT_SCOPE="$scope" CLAUDE_TEMPLATE="$templates/CLAUDE.md" CODEX_TEMPLATE="$templates/AGENTS.md" \
    bash "$ROOT/scripts/seed-project-instructions.sh" "$scope/example/src"

  if [ -e "$outside/CLAUDE.md" ] || [ -e "$outside/AGENTS.md" ] || [ -e "$outside/.gitignore" ]; then
    printf 'seed project wrote through symlinked project root\n' >&2
    exit 1
  fi
}

optimizer_rejects_symlinked_targets() {
  local project outside

  project="$tmp/safe-project"
  outside="$tmp/outside-target"
  mkdir -p "$project/.claude" "$outside"
  ln -s "$outside/gitignore" "$project/.gitignore"
  ln -s "$outside/settings.local.json" "$project/.claude/settings.local.json"

  bash "$ROOT/scripts/optimize-ai.sh" "$project"

  if [ -e "$outside/gitignore" ] || [ -e "$outside/settings.local.json" ]; then
    printf 'optimizer wrote through symlinked managed target\n' >&2
    exit 1
  fi
}

powershell_rejects_symlinked_paths() {
  command -v pwsh >/dev/null 2>&1 || return 0

  local scope outside templates project ps_project ps_outside

  scope="$tmp/ps-projects"
  outside="$tmp/ps-outside"
  templates="$tmp/ps-templates"
  mkdir -p "$scope" "$outside" "$templates"
  ln -s "$outside" "$scope/example"
  printf '# Claude\n' > "$templates/CLAUDE.md"
  printf '# Codex\n' > "$templates/AGENTS.md"

  PROJECT_SCOPE="$scope" CLAUDE_TEMPLATE="$templates/CLAUDE.md" CODEX_TEMPLATE="$templates/AGENTS.md" \
    pwsh -NoProfile -File "$ROOT/scripts/seed-project-instructions.ps1" -Cwd "$scope/example/src"

  if [ -e "$outside/CLAUDE.md" ] || [ -e "$outside/AGENTS.md" ] || [ -e "$outside/.gitignore" ]; then
    printf 'PowerShell seed project wrote through symlinked project root\n' >&2
    exit 1
  fi

  ps_project="$tmp/ps-safe-project"
  ps_outside="$tmp/ps-outside-target"
  mkdir -p "$ps_project/.claude" "$ps_outside"
  ln -s "$ps_outside/gitignore" "$ps_project/.gitignore"
  ln -s "$ps_outside/settings.local.json" "$ps_project/.claude/settings.local.json"

  pwsh -NoProfile -File "$ROOT/scripts/optimize-ai.ps1" -Project "$ps_project"

  if [ -e "$ps_outside/gitignore" ] || [ -e "$ps_outside/settings.local.json" ]; then
    printf 'PowerShell optimizer wrote through symlinked managed target\n' >&2
    exit 1
  fi
}

powershell_seeds_regular_project() {
  command -v pwsh >/dev/null 2>&1 || return 0

  local scope templates project

  scope="$tmp/ps-regular-projects"
  templates="$tmp/ps-regular-templates"
  project="$scope/example"
  mkdir -p "$project" "$templates"
  printf '# Claude\n' > "$templates/CLAUDE.md"
  printf '# Codex\n' > "$templates/AGENTS.md"

  PROJECT_SCOPE="$scope" CLAUDE_TEMPLATE="$templates/CLAUDE.md" CODEX_TEMPLATE="$templates/AGENTS.md" \
    pwsh -NoProfile -File "$ROOT/scripts/seed-project-instructions.ps1" -Cwd "$project/src"

  test -f "$project/CLAUDE.md"
  test -f "$project/AGENTS.md"
  test -f "$project/.gitignore"
  test -f "$project/.codexignore"
  test -f "$project/.claude/settings.local.json"
}

bootstrap_rejects_tampered_archive
install_defaults_skip_unverified_remote_commands
powershell_defaults_skip_unverified_remote_commands
seed_rejects_symlinked_project_root
optimizer_rejects_symlinked_targets
powershell_rejects_symlinked_paths
powershell_seeds_regular_project

printf 'security-regression.sh: OK\n'
