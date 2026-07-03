#!/usr/bin/env bash

# Require Context7 credentials before any MCP configuration command can run.
require_context7_credentials() {
  if [ -z "${CONTEXT7_API_KEY:-}" ]; then
    printf 'error: Context7 credentials are required before stack configuration.\n' >&2
    printf 'Create a Context7 API key, then rerun with:\n' >&2
    printf 'export CONTEXT7_API_KEY="your-context7-api-key"\n' >&2
    printf 'No Context7 configuration was written.\n' >&2
    printf 'Log: %s\n' "$install_log" >&2
    log_line "context7_credentials=missing"
    exit 1
  fi

  log_line "context7_credentials=present"
}

# Run one stack command with a short stdout label while preserving the exact
# redacted command in the install log for troubleshooting.
run_stack_command() {
  local dry_run_label="$1"
  shift

  if [ "$dry_run" = "1" ]; then
    status_dry_run "$dry_run_label"
  fi
  run_logged "$@"
  if [ "$dry_run" = "0" ]; then
    status_ok "$dry_run_label"
  fi
}

# Merge the local Context7 MCP server into Claude Desktop's config without
# logging the raw API key.
configure_claude_desktop_context7() {
  local config
  local backup

  config="$(claude_desktop_config_path)"
  if [ "$dry_run" = "1" ]; then
    status_dry_run "Configure Context7 for Claude Desktop $config"
    log_line "update_claude_desktop_config=$config server=context7"
    return 0
  fi

  if [ -e "$config" ]; then
    backup="$(backup_path "$config")"
    status_ok "Backing up $config to $backup"
    mkdir -p "$(dirname "$config")"
    cp "$config" "$backup"
  fi

  mkdir -p "$(dirname "$config")"
  CONTEXT7_API_KEY="$CONTEXT7_API_KEY" node - "$config" <<'NODE'
const fs = require("fs");

const configPath = process.argv[2];
const apiKey = process.env.CONTEXT7_API_KEY;
let config = {};

if (fs.existsSync(configPath) && fs.readFileSync(configPath, "utf8").trim()) {
  config = JSON.parse(fs.readFileSync(configPath, "utf8"));
}

if (!config || Array.isArray(config) || typeof config !== "object") {
  throw new Error("Claude Desktop config must be a JSON object");
}

if (!config.mcpServers || Array.isArray(config.mcpServers) || typeof config.mcpServers !== "object") {
  config.mcpServers = {};
}

config.mcpServers.context7 = {
  command: "npx",
  args: ["-y", "@upstash/context7-mcp"],
  env: {
    CONTEXT7_API_KEY: apiKey
  }
};

fs.writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);
NODE
  status_ok "Configure Context7 for Claude Desktop $config"
  log_line "update_claude_desktop_config=$config server=context7"
}

# Install LeanCTX when missing and switch it to the minimal tool profile.
install_leanctx() {
  step "Install LeanCTX"
  if command -v lean-ctx >/dev/null 2>&1; then
    status_ok "LeanCTX already installed"
    log_line "leanctx=present"
  else
    run_stack_command "Install LeanCTX" sh -c "curl -fsSL https://leanctx.com/install.sh | sh"
  fi

  if command -v lean-ctx >/dev/null 2>&1 || [ "$dry_run" = "1" ]; then
    run_stack_command "Configure LeanCTX tools" lean-ctx tools minimal
  fi
}

# Register the Context7 MCP server for each selected AI product and detected
# product surface.
configure_context7() {
  step "Configure Context7"
  require_context7_credentials

  if tool_enabled codex; then
    run_stack_command "Configure Context7 for Codex" codex mcp add context7 -- npx -y @upstash/context7-mcp --api-key "$CONTEXT7_API_KEY"
  fi

  if tool_enabled claude && claude_cli_available; then
    run_stack_command "Configure Context7 for Claude Code" claude mcp add --scope user --header "CONTEXT7_API_KEY: $CONTEXT7_API_KEY" --transport http context7 https://mcp.context7.com/mcp
  elif tool_enabled claude; then
    status_skipped "Claude Code CLI not found; skipped Claude Code Context7"
  fi

  if tool_enabled claude && claude_desktop_available; then
    configure_claude_desktop_context7
  elif tool_enabled claude; then
    status_skipped "Claude Desktop app not found; skipped Desktop Context7"
  fi
}

# Install Caveman support for each selected AI product and detected CLI surface.
install_caveman() {
  step "Install Caveman"
  if tool_enabled codex; then
    run_stack_command "Install Caveman for Codex" npx skills add JuliusBrussee/caveman -a codex
  fi

  if tool_enabled claude && claude_cli_available; then
    run_stack_command "Install Caveman for Claude Code" sh -c "claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman"
  elif tool_enabled claude; then
    status_skipped "Claude Code CLI not found; skipped Caveman for Claude Code"
  fi
}

# Install Superpowers support by cloning its repository and linking its skills
# into the selected client's skill directory.
install_superpowers() {
  step "Install Superpowers"
  if tool_enabled codex; then
    run_stack_command "Install Superpowers for Codex" sh -c "if [ -d \"$HOME/.codex/superpowers/.git\" ]; then git -C \"$HOME/.codex/superpowers\" pull; else git clone https://github.com/obra/superpowers.git \"$HOME/.codex/superpowers\"; fi"
    run_stack_command "Prepare Superpowers skills directory for Codex" mkdir -p "$HOME/.agents/skills"
    run_stack_command "Link Superpowers skills for Codex" ln -sfn "$HOME/.codex/superpowers/skills" "$HOME/.agents/skills/superpowers"
  fi

  if tool_enabled claude && claude_cli_available; then
    run_stack_command "Install Superpowers for Claude Code" sh -c "if [ -d \"$HOME/.claude/superpowers/.git\" ]; then git -C \"$HOME/.claude/superpowers\" pull; else git clone https://github.com/obra/superpowers.git \"$HOME/.claude/superpowers\"; fi"
    run_stack_command "Prepare Superpowers skills directory for Claude Code" mkdir -p "$HOME/.claude/skills"
    run_stack_command "Link Superpowers skills for Claude Code" ln -sfn "$HOME/.claude/superpowers/skills" "$HOME/.claude/skills/superpowers"
  elif tool_enabled claude; then
    status_skipped "Claude Code CLI not found; skipped Superpowers for Claude Code"
  fi
}

# Run every stack-tool setup step in the required order.
install_stack_tools() {
  install_leanctx
  configure_context7
  install_caveman
  install_superpowers
}
