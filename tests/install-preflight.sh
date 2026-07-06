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

# Assert that a path was not created.
assert_not_exists() {
  [ ! -e "$1" ] || {
    printf 'expected path not to exist: %s\n' "$1" >&2
    exit 1
  }
}

# Verify non-interactive installs stop when rtk is present because it conflicts
# with LeanCTX.
rtk_conflict_stops_non_interactive_install() {
  local home="$tmp/home-rtk-conflict-noninteractive"
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  printf '#!/usr/bin/env bash\nprintf "rtk should not run\\n" >> "$HOME/commands.log"\nexit 0\n' > "$home/bin/rtk"
  chmod +x "$home/bin/codex" "$home/bin/rtk"

  if HOME="$home" PATH="$home/bin:/usr/bin:/bin" CONTEXT7_API_KEY=test-key \
    bash "$ROOT/scripts/install.sh" --non-interactive --targets codex >"$tmp/rtk-noninteractive.out" 2>"$tmp/rtk-noninteractive.err"; then
    printf 'rtk conflict unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/rtk-noninteractive.out")" "Warning rtk found; rtk conflicts with lean-ctx. Resolved as: $home/bin/rtk"
  assert_contains "$(cat "$tmp/rtk-noninteractive.err")" "conflicting tool for lean-ctx: rtk"
  assert_contains "$(cat "$tmp/rtk-noninteractive.err")" "Run rtk init -g --uninstall, then rerun this installer."
  assert_not_exists "$home/commands.log"
  assert_not_exists "$home/.codex/AGENTS.md"
}

# Verify dry runs report the rtk uninstall command without executing it.
rtk_conflict_dry_run_reports_uninstall_command() {
  local home="$tmp/home-rtk-conflict-dry-run"
  local output
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  printf '#!/usr/bin/env bash\nprintf "rtk should not run\\n" >> "$HOME/commands.log"\nexit 0\n' > "$home/bin/rtk"
  chmod +x "$home/bin/codex" "$home/bin/rtk"

  output="$(
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" CONTEXT7_API_KEY=test-key \
      bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets codex
  )"

  assert_contains "$output" "Warning rtk found; rtk conflicts with lean-ctx. Resolved as: $home/bin/rtk"
  assert_contains "$output" "Dry run Run rtk init -g --uninstall, then verify rtk is no longer on PATH"
  assert_not_exists "$home/commands.log"
}

# Verify interactive preflight executes the rtk uninstall command after a yes
# answer.
interactive_rtk_conflict_runs_uninstall_command() {
  local home="$tmp/home-rtk-conflict-interactive"
  local output
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nprintf "%s\\n" "$*" >> "$HOME/commands.log"\nrm -f "$0"\nexit 0\n' > "$home/bin/rtk"
  chmod +x "$home/bin/rtk"

  output="$(
    printf 'y\n' | HOME="$home" PATH="$home/bin:/usr/bin:/bin" bash -c '
      ROOT="$1"
      agents_home="$HOME/.agents"
      dry_run=0
      non_interactive=0
      say() { printf "%s\n" "$*"; }
      die() { printf "error: %s\n" "$*" >&2; exit 1; }
      run() { "$@"; }
      . "$ROOT/scripts/lib/targets.sh"
      . "$ROOT/scripts/lib/logging.sh"
      . "$ROOT/scripts/lib/preflight.sh"
      prompt_yes_no() {
        local prompt="$1"
        local default="$2"
        local answer suffix
        if [ "$default" = "yes" ]; then
          suffix="[Y/n]"
        else
          suffix="[y/N]"
        fi
        printf "%s %s " "$prompt" "$suffix"
        read_prompt_value answer
        answer="${answer:-$default}"
        case "$answer" in
          y|Y|yes|YES) return 0 ;;
          *) return 1 ;;
        esac
      }
      preflight_rtk_conflict
    ' sh "$ROOT"
  )"

  assert_contains "$output" "Warning rtk found; rtk conflicts with lean-ctx."
  assert_contains "$output" "Uninstall rtk before installing LeanCTX? [Y/n]"
  assert_contains "$output" "OK rtk uninstall command completed"
  assert_contains "$(cat "$home/.agents/install.log")" "command=rtk init -g --uninstall"
  assert_contains "$(cat "$home/.agents/install.log")" "rtk_uninstall=completed"
}

# Verify interactive preflight does not continue if the rtk uninstall command
# succeeds but leaves rtk resolvable on PATH.
interactive_rtk_conflict_stops_when_uninstall_leaves_rtk() {
  local home="$tmp/home-rtk-conflict-still-present"
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nprintf "%s\\n" "$*" >> "$HOME/commands.log"\nexit 0\n' > "$home/bin/rtk"
  chmod +x "$home/bin/rtk"

  if printf 'y\n' | HOME="$home" PATH="$home/bin:/usr/bin:/bin" bash -c '
    ROOT="$1"
    agents_home="$HOME/.agents"
    dry_run=0
    non_interactive=0
    say() { printf "%s\n" "$*"; }
    die() { printf "error: %s\n" "$*" >&2; exit 1; }
    run() { "$@"; }
    . "$ROOT/scripts/lib/targets.sh"
    . "$ROOT/scripts/lib/logging.sh"
    . "$ROOT/scripts/lib/preflight.sh"
    prompt_yes_no() {
      local prompt="$1"
      local default="$2"
      local answer suffix
      if [ "$default" = "yes" ]; then
        suffix="[Y/n]"
      else
        suffix="[y/N]"
      fi
      printf "%s %s " "$prompt" "$suffix"
      read_prompt_value answer
      answer="${answer:-$default}"
      case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
      esac
    }
    preflight_rtk_conflict
  ' sh "$ROOT" >"$tmp/rtk-still-present.out" 2>"$tmp/rtk-still-present.err"; then
    printf 'rtk conflict unexpectedly continued after incomplete uninstall\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/rtk-still-present.out")" "Warning rtk found; rtk conflicts with lean-ctx. Resolved as: $home/bin/rtk"
  assert_contains "$(cat "$tmp/rtk-still-present.err")" "The rtk uninstall command completed, but rtk still resolves on PATH at: $home/bin/rtk"
  assert_contains "$(cat "$tmp/rtk-still-present.err")" "Remove that executable or shim, open a fresh shell if needed, then rerun this installer."
  assert_contains "$(cat "$home/.agents/install.log")" "command=rtk init -g --uninstall"
}

# Verify missing Codex stops the install before managed files are written.
missing_codex_stops_before_changes() {
  local home="$tmp/home-missing-codex"
  mkdir -p "$home"

  if HOME="$home" PATH="/usr/bin:/bin" CONTEXT7_API_KEY=test-key \
    bash "$ROOT/scripts/install.sh" --non-interactive --targets codex >"$tmp/codex.out" 2>"$tmp/codex.err"; then
    printf 'missing codex unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/codex.err")" "missing prerequisite for codex: codex"
  assert_contains "$(cat "$tmp/codex.err")" "No files or configuration were changed."
  assert_not_exists "$home/.codex/AGENTS.md"
  assert_not_exists "$home/.agents/scripts/seed-project-instructions.sh"
}

# Verify missing Claude surfaces stop the install before Claude files are
# written.
missing_claude_surfaces_stop_before_changes() {
  local home="$tmp/home-missing-claude"
  mkdir -p "$home"

  if HOME="$home" PATH="/usr/bin:/bin" CONTEXT7_API_KEY=test-key \
    CLAUDE_DESKTOP_APP_PATH="$home/missing/Claude.app" \
    bash "$ROOT/scripts/install.sh" --non-interactive --targets claude >"$tmp/claude.out" 2>"$tmp/claude.err"; then
    printf 'missing claude unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/claude.err")" "missing prerequisite for claude: Claude Desktop or claude CLI"
  assert_contains "$(cat "$tmp/claude.err")" "Install Claude Desktop, install the Claude Code CLI, or both."
  assert_not_exists "$home/.claude/CLAUDE.md"
}

# Verify Claude Desktop alone is enough for the Claude product target when the
# local MCP runtime commands are available.
claude_desktop_without_cli_passes_preflight() {
  local home="$tmp/home-claude-desktop-only"
  local output
  mkdir -p "$home/bin" "$home/Applications/Claude.app"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/node"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/npx"
  chmod +x "$home/bin/node" "$home/bin/npx"

  output="$(
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" CONTEXT7_API_KEY=test-key \
      CLAUDE_DESKTOP_APP_PATH="$home/Applications/Claude.app" \
      bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets claude
  )"

  assert_contains "$output" "OK Claude"
  assert_contains "$output" "OK Claude Desktop found"
  assert_contains "$output" "Skipped Claude Code CLI not found"
  assert_contains "$output" "Dry run Configure Context7 for Claude Desktop"
}

# Verify Claude target-mode setup requires an Anthropic key for LeanCTX proxy.
missing_claude_anthropic_key_stops_before_changes() {
  local home="$tmp/home-claude-missing-anthropic"
  mkdir -p "$home/bin" "$home/Applications/Claude.app"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/node"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/npx"
  chmod +x "$home/bin/node" "$home/bin/npx"

  if HOME="$home" PATH="$home/bin:/usr/bin:/bin" CONTEXT7_API_KEY="test-context7" \
    CLAUDE_DESKTOP_APP_PATH="$home/Applications/Claude.app" \
    bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets claude --enable-claude-proxy >"$tmp/claude-anthropic.out" 2>"$tmp/claude-anthropic.err"; then
    printf 'missing Anthropic key unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/claude-anthropic.err")" "missing prerequisite for claude: Anthropic API key"
  assert_contains "$(cat "$tmp/claude-anthropic.err")" "export ANTHROPIC_API_KEY="
  assert_not_exists "$home/.claude/CLAUDE.md"
}

# Verify Claude Code CLI setup requires npx for skills-based Caveman installs.
claude_cli_without_npx_stops_before_changes() {
  local home="$tmp/home-claude-cli-without-npx"
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/claude"
  chmod +x "$home/bin/claude"

  if HOME="$home" PATH="$home/bin:/usr/bin:/bin" CONTEXT7_API_KEY=test-key \
    CLAUDE_DESKTOP_APP_PATH="$home/missing/Claude.app" \
    bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets claude >"$tmp/claude-cli-npx.out" 2>"$tmp/claude-cli-npx.err"; then
    printf 'missing Claude Code npx unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$(cat "$tmp/claude-cli-npx.err")" "missing prerequisite for claude: npx"
  assert_contains "$(cat "$tmp/claude-cli-npx.err")" "Install Node.js/npm so this installer can install Claude Code skills."
  assert_not_exists "$home/.claude/CLAUDE.md"
}

# Verify interactive target-mode installs can collect the Context7 API key
# during preflight before stack setup begins.
interactive_claude_prompts_for_context7_key() {
  local home="$tmp/home-claude-context7-prompt"
  local output log
  mkdir -p "$home/bin" "$home/Applications/Claude.app"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/node"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/npx"
  chmod +x "$home/bin/node" "$home/bin/npx"

  output="$(
    printf 'prompted-context7-key\nn\nn\n' | HOME="$home" PATH="$home/bin:/usr/bin:/bin" \
      CLAUDE_DESKTOP_APP_PATH="$home/Applications/Claude.app" \
      bash "$ROOT/scripts/install.sh" --dry-run --targets claude
  )"
  log="$home/.agents/install.log"

  assert_contains "$output" "Enter Context7 API key"
  assert_contains "$output" "OK Context7 API key provided"
  assert_contains "$output" "Enable LeanCTX proxy for Claude? Requires ANTHROPIC_API_KEY. [y/N]"
  assert_contains "$output" "Skipped LeanCTX proxy for Claude disabled"
  assert_contains "$output" "Dry run Configure Context7 for Claude Desktop"
  assert_contains "$(cat "$log")" "context7_credentials=present"
  assert_contains "$(cat "$log")" "claude_proxy=disabled"
  assert_contains "$(cat "$log")" "CONTEXT7_API_KEY=<redacted>"
}

# Run the preflight scenarios.
rtk_conflict_stops_non_interactive_install
rtk_conflict_dry_run_reports_uninstall_command
interactive_rtk_conflict_runs_uninstall_command
interactive_rtk_conflict_stops_when_uninstall_leaves_rtk
missing_codex_stops_before_changes
missing_claude_surfaces_stop_before_changes
claude_desktop_without_cli_passes_preflight
missing_claude_anthropic_key_stops_before_changes
claude_cli_without_npx_stops_before_changes
interactive_claude_prompts_for_context7_key

printf 'install-preflight.sh: OK\n'
