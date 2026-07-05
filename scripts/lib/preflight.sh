#!/usr/bin/env bash

# Report a missing prerequisite and stop before the installer changes files.
preflight_die() {
  local target="$1"
  local prerequisite="$2"
  shift 2

  printf 'error: missing prerequisite for %s: %s\n' "$target" "$prerequisite" >&2
  for instruction in "$@"; do
    printf '%s\n' "$instruction" >&2
  done
  printf 'No files or configuration were changed.\n' >&2
  printf 'Log: %s\n' "$install_log" >&2
  log_line "preflight_failure target=$target prerequisite=$prerequisite"
  exit 1
}

# Report a conflicting tool and stop before the installer changes files.
preflight_conflict_die() {
  local target="$1"
  local tool="$2"
  shift 2

  printf 'error: conflicting tool for %s: %s\n' "$target" "$tool" >&2
  for instruction in "$@"; do
    printf '%s\n' "$instruction" >&2
  done
  printf 'No files or configuration were changed.\n' >&2
  printf 'Log: %s\n' "$install_log" >&2
  log_line "preflight_conflict target=$target tool=$tool"
  exit 1
}

# Verify one command required by one target surface is available on PATH.
require_command_for_target() {
  local target="$1"
  local command_name="$2"
  local instructions="$3"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    preflight_die "$target" "$command_name" "$instructions"
  fi

  log_line "preflight_ok target=$target command=$command_name"
  status_ok "$command_name found for $target"
}

# Read a secret value without echoing it when an interactive terminal is
# available, while still supporting piped test/bootstrap input.
read_secret_value() {
  local var_name="$1"
  local value=""

  if [ -t 0 ]; then
    if IFS= read -rs value; then
      printf '\n'
      printf -v "$var_name" '%s' "$value"
      return 0
    fi
  fi

  if [ "${TOKEN_SAVER_PROMPT_TTY:-0}" = "1" ] && [ -r /dev/tty ] && [ -w /dev/tty ]; then
    if IFS= read -rs value 2>/dev/null < /dev/tty; then
      printf '\n'
      printf -v "$var_name" '%s' "$value"
      return 0
    fi
  fi

  read_prompt_value "$var_name"
}

# Require Context7 credentials before stack setup begins. Interactive installs
# can provide the key once and reuse it for later MCP configuration commands.
preflight_context7_credentials() {
  local api_key=""

  if [ -n "${CONTEXT7_API_KEY:-}" ]; then
    log_line "context7_credentials=present"
    status_ok "Context7 API key provided"
    return 0
  fi

  if [ "$non_interactive" = "0" ]; then
    printf 'Enter Context7 API key (get key from https://context7.com/): '
    read_secret_value api_key
    if [ -n "$api_key" ]; then
      CONTEXT7_API_KEY="$api_key"
      export CONTEXT7_API_KEY
      log_line "context7_credentials=present"
      log_line "CONTEXT7_API_KEY=$CONTEXT7_API_KEY"
      status_ok "Context7 API key provided"
      return 0
    fi
  fi

  preflight_die "selected targets" "Context7 API key" "Create a Context7 API key, then rerun with:" "export CONTEXT7_API_KEY=\"your-context7-api-key\""
}

# Require Anthropic credentials for Claude proxy setup. Interactive installs can
# provide the key once and reuse it when LeanCTX enables the proxy.
preflight_anthropic_credentials() {
  local api_key=""

  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    log_line "anthropic_credentials=present"
    status_ok "Anthropic API key provided"
    return 0
  fi

  if [ "$non_interactive" = "0" ]; then
    printf 'Enter Anthropic API key for LeanCTX Claude proxy: '
    read_secret_value api_key
    if [ -n "$api_key" ]; then
      ANTHROPIC_API_KEY="$api_key"
      export ANTHROPIC_API_KEY
      log_line "anthropic_credentials=present"
      log_line "ANTHROPIC_API_KEY=[REDACTED:API key param]"
      status_ok "Anthropic API key provided"
      return 0
    fi
  fi

  preflight_die "claude" "Anthropic API key" "Create an Anthropic API key, then rerun with:" "export ANTHROPIC_API_KEY=[REDACTED:API key param]\"your-anthropic-api-key\""
}

# RTK rewrites and compresses shell commands before agents see output, which
# conflicts with LeanCTX's own shell/context layer.
preflight_rtk_conflict() {
  if ! command -v rtk >/dev/null 2>&1; then
    return 0
  fi

  log_line "preflight_conflict target=lean-ctx tool=rtk"
  status_warning "rtk found; rtk conflicts with lean-ctx."

  if [ "$dry_run" = "1" ]; then
    status_dry_run "Run rtk init -g --uninstall"
    return 0
  fi

  if [ "$non_interactive" = "0" ] && prompt_yes_no "Uninstall rtk before installing LeanCTX?" "yes"; then
    if run_logged rtk init -g --uninstall; then
      status_ok "rtk uninstall command completed"
      log_line "rtk_uninstall=completed"
      return 0
    fi
    preflight_conflict_die "lean-ctx" "rtk" \
      "rtk conflicts with lean-ctx." \
      "The rtk uninstall command failed. Run rtk init -g --uninstall, then rerun this installer."
  fi

  preflight_conflict_die "lean-ctx" "rtk" \
    "rtk conflicts with lean-ctx." \
    "Run rtk init -g --uninstall, then rerun this installer."
}

# Check that at least one Claude product surface is available, then verify the
# runtime commands needed by each detected surface.
preflight_claude() {
  local has_cli=0
  local has_desktop=0

  claude_cli_available && has_cli=1
  claude_desktop_available && has_desktop=1

  if [ "$has_cli" = "0" ] && [ "$has_desktop" = "0" ]; then
    preflight_die "claude" "Claude Desktop or claude CLI" "Install Claude Desktop, install the Claude Code CLI, or both."
  fi

  if [ "$has_cli" = "1" ]; then
    log_line "preflight_ok target=claude command=claude"
    status_ok "claude found for claude"
    require_command_for_target "claude" "npx" "Install Node.js/npm so this installer can install Claude Code skills."
  else
    status_skipped "Claude Code CLI not found; skipping CLI-only setup"
  fi

  if [ "$has_desktop" = "1" ]; then
    log_line "preflight_ok target=claude app=$(claude_desktop_app_path)"
    status_ok "Claude Desktop found"
    require_command_for_target "claude" "node" "Install Node.js so this installer can update Claude Desktop MCP configuration."
    require_command_for_target "claude" "npx" "Install Node.js/npm so Claude Desktop can launch the Context7 MCP server."
  else
    status_skipped "Claude Desktop app not found; skipping Desktop MCP config"
  fi
}

# Check only the prerequisites needed by the selected products and detected
# product surfaces.
preflight_targets() {
  step "Preflight selected targets"

  if target_enabled codex; then
    require_command_for_target "codex" "codex" "Install Codex before running this installer."
  fi

  if target_enabled claude; then
    preflight_claude
  fi

  if target_enabled vscode; then
    log_line "preflight_ok target=vscode"
    status_ok "VS Code found"
    require_command_for_target "vscode" "node" "Install Node.js so this installer can update VS Code MCP configuration."
    require_command_for_target "vscode" "npx" "Install Node.js/npm so VS Code can launch the Context7 MCP server."
  fi

  preflight_rtk_conflict
  preflight_context7_credentials

  if target_enabled claude && [ "$claude_proxy_enabled" = "0" ] && [ "$non_interactive" = "0" ]; then
    if prompt_yes_no "Enable LeanCTX proxy for Claude? Requires ANTHROPIC_API_KEY." "no"; then
      claude_proxy_enabled=1
    fi
  fi

  if target_enabled claude && [ "$claude_proxy_enabled" = "1" ]; then
    log_line "claude_proxy=enabled"
    preflight_anthropic_credentials
  elif target_enabled claude; then
    status_skipped "LeanCTX proxy for Claude disabled"
    log_line "claude_proxy=disabled"
  fi
}
