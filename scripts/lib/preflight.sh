#!/usr/bin/env bash

# Report a missing prerequisite and stop before the installer changes files.
preflight_die() {
  local target="$1"
  local prerequisite="$2"
  shift 2

  printf 'error: missing prerequisite for %s: %s\n' "$target" "$prerequisite" >&2
  printf '%s\n' "$*" >&2
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
}

# Check only the prerequisites needed by the selected target surfaces.
preflight_targets() {
  step "Preflight selected targets"

  if target_enabled codex-desktop; then
    require_command_for_target "codex-desktop" "codex" "Install Codex before running this installer."
  fi

  if target_enabled codex-vscode; then
    require_command_for_target "codex-vscode" "codex" "Install Codex before running this installer."
    require_command_for_target "codex-vscode" "code" "Install VS Code and enable the code shell command."
  fi

  if target_enabled claude-desktop; then
    require_command_for_target "claude-desktop" "claude" "Install Claude Code before running this installer."
  fi

  if target_enabled claude-vscode; then
    require_command_for_target "claude-vscode" "claude" "Install Claude Code before running this installer."
    require_command_for_target "claude-vscode" "code" "Install VS Code and enable the code shell command."
  fi
}
