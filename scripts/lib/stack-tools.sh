#!/usr/bin/env bash

# Require Context7 credentials before any MCP configuration command can run.
require_context7_credentials() {
  if [ -z "${CONTEXT7_API_KEY:-}" ]; then
    printf 'error: Context7 credentials are required before stack configuration.\n' >&2
    printf 'Create a Context7 API key, then rerun with:\n' >&2
    printf 'export CONTEXT7_API_KEY="your-context7-api-key"\n' >&2
    printf 'No Context7 configuration was written.\n' >&2
    log_line "context7_credentials=missing"
    exit 1
  fi

  log_line "context7_credentials=present"
}

# Install LeanCTX when missing and switch it to the minimal tool profile.
install_leanctx() {
  step "Install LeanCTX"
  if command -v lean-ctx >/dev/null 2>&1; then
    say "LeanCTX already installed"
    log_line "leanctx=present"
  else
    run_logged sh -c "curl -fsSL https://leanctx.com/install.sh | sh"
  fi

  if command -v lean-ctx >/dev/null 2>&1 || [ "$dry_run" = "1" ]; then
    run_logged lean-ctx tools minimal
  fi
}

# Register the Context7 MCP server for each selected AI client.
configure_context7() {
  step "Configure Context7"
  require_context7_credentials

  if tool_enabled codex; then
    run_logged codex mcp add context7 -- npx -y @upstash/context7-mcp --api-key "$CONTEXT7_API_KEY"
  fi

  if tool_enabled claude; then
    run_logged claude mcp add --scope user --header "CONTEXT7_API_KEY: $CONTEXT7_API_KEY" --transport http context7 https://mcp.context7.com/mcp
  fi
}

# Install Caveman support for each selected AI client.
install_caveman() {
  step "Install Caveman"
  if tool_enabled codex; then
    run_logged npx skills add JuliusBrussee/caveman -a codex
  fi

  if tool_enabled claude; then
    run_logged sh -c "claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman"
  fi
}

# Install Superpowers support by cloning its repository and linking its skills
# into the selected client's skill directory.
install_superpowers() {
  step "Install Superpowers"
  if tool_enabled codex; then
    run_logged sh -c "if [ -d \"$HOME/.codex/superpowers/.git\" ]; then git -C \"$HOME/.codex/superpowers\" pull; else git clone https://github.com/obra/superpowers.git \"$HOME/.codex/superpowers\"; fi"
    run_logged mkdir -p "$HOME/.agents/skills"
    run_logged ln -sfn "$HOME/.codex/superpowers/skills" "$HOME/.agents/skills/superpowers"
  fi

  if tool_enabled claude; then
    run_logged sh -c "if [ -d \"$HOME/.claude/superpowers/.git\" ]; then git -C \"$HOME/.claude/superpowers\" pull; else git clone https://github.com/obra/superpowers.git \"$HOME/.claude/superpowers\"; fi"
    run_logged mkdir -p "$HOME/.claude/skills"
    run_logged ln -sfn "$HOME/.claude/superpowers/skills" "$HOME/.claude/skills/superpowers"
  fi
}

# Run every stack-tool setup step in the required order.
install_stack_tools() {
  install_leanctx
  configure_context7
  install_caveman
  install_superpowers
}
