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

# Read the Context7 API key without echoing it when an interactive terminal is
# available, while still supporting piped test/bootstrap input.
read_context7_api_key() {
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
    read_context7_api_key api_key
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

  preflight_context7_credentials
}
