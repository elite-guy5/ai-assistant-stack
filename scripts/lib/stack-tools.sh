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

stack_command_output_is_idempotent() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    *"already exists"*|*"already installed"*|*"already configured"*|*"already present"*) return 0 ;;
    *) return 1 ;;
  esac
}

# Run one stack command with a short stdout label while preserving the exact
# redacted command in the install log for troubleshooting. Upstream tools often
# return nonzero for idempotent setup attempts; treat their explicit "already"
# responses as success so the stack install can continue.
run_stack_command() {
  local dry_run_label="$1"
  local output
  local status
  shift

  if [ "$dry_run" = "1" ]; then
    status_dry_run "$dry_run_label"
    run_logged "$@"
    return 0
  fi

  output="$(mktemp)"
  log_line "command=$*"
  if "$@" >"$output" 2>&1; then
    redact_text < "$output"
    rm -f "$output"
    status_ok "$dry_run_label"
    return 0
  else
    status=$?
  fi

  if stack_command_output_is_idempotent "$(cat "$output")"; then
    redact_text < "$output"
    rm -f "$output"
    log_line "idempotent_command=$* exit_status=$status"
    status_ok "$dry_run_label already configured"
    return 0
  fi

  redact_text < "$output" >&2
  rm -f "$output"
  return "$status"
}

json_array_contains_field_value() {
  local label="$1"
  local field="$2"
  local expected="$3"

  command -v node >/dev/null 2>&1 || die "node is required to parse $label JSON output"

  node -e '
const label = process.argv[1];
const field = process.argv[2];
const expected = process.argv[3];
let input = "";

process.stdin.on("data", chunk => {
  input += chunk;
});

process.stdin.on("end", () => {
  let parsed;
  if (input.trim() === "") {
    console.error(`invalid JSON from ${label}: empty output`);
    process.exit(2);
  }

  try {
    parsed = JSON.parse(input);
  } catch (error) {
    console.error(`invalid JSON from ${label}: ${error.message}`);
    process.exit(2);
  }

  if (!Array.isArray(parsed)) {
    console.error(`invalid JSON from ${label}: expected array`);
    process.exit(2);
  }

  process.exit(parsed.some(item => item && item[field] === expected) ? 0 : 1);
});
' "$label" "$field" "$expected"
}

agent_skill_installed() {
  local label="$1"
  local agent="$2"
  local skill="$3"
  local output
  local parse_error
  local status
  local stderr_file
  local stderr

  if [ "$dry_run" = "1" ]; then
    status_dry_run "Check $label skill $skill"
    return 1
  fi

  stderr_file="$(mktemp)"
  if output="$(npx skills list --json --global --agent "$agent" 2>"$stderr_file")"; then
    rm -f "$stderr_file"
  else
    stderr="$(cat "$stderr_file")"
    rm -f "$stderr_file"
    if [ -n "$stderr" ]; then
      die "failed to list $label skills: $stderr"
    fi
    die "failed to list $label skills: $output"
  fi

  if parse_error="$(printf '%s\n' "$output" | json_array_contains_field_value "npx skills list" "name" "$skill" 2>&1)"; then
    return 0
  else
    status=$?
  fi

  [ "$status" -eq 1 ] && return 1
  die "$parse_error"
}

codex_skill_installed() {
  local skill="$1"
  agent_skill_installed "Codex" codex "$skill"
}

claude_code_skill_installed() {
  local skill="$1"
  agent_skill_installed "Claude Code" claude-code "$skill"
}

codex_plugin_installed() {
  local plugin="$1"
  local output
  local status

  if [ "$dry_run" = "1" ]; then
    status_dry_run "Check Codex plugin $plugin"
    return 1
  fi

  output="$(codex plugin list 2>&1)" || die "failed to list Codex plugins: $output"
  if printf '%s\n' "$output" | awk -v plugin="$plugin" '
    NF == 0 { next }
    $1 == "Marketplace" { next }
    $0 ~ /^\// { next }
    $1 == "PLUGIN" && $2 == "STATUS" { valid_header = 1; next }
    $1 == plugin && $0 ~ /not installed/ { missing = 1; next }
    $1 == plugin && $0 ~ /installed/ { found = 1; next }
    $1 == plugin { invalid = 1 }
    $0 ~ /not installed/ || $0 ~ /installed/ { next }
    { invalid = 1 }
    END {
      if (!valid_header || invalid) exit 2
      if (found) exit 0
      exit 1
    }
  '; then
    return 0
  else
    status=$?
  fi

  [ "$status" -lt 2 ] && return "$status"
  die "invalid output from codex plugin list"
}

claude_plugin_installed() {
  local plugin="$1"
  local output
  local parse_error
  local status
  local stderr_file
  local stderr

  if [ "$dry_run" = "1" ]; then
    status_dry_run "Check Claude Code plugin $plugin"
    return 1
  fi

  stderr_file="$(mktemp)"
  if output="$(claude plugin list --json 2>"$stderr_file")"; then
    rm -f "$stderr_file"
  else
    stderr="$(cat "$stderr_file")"
    rm -f "$stderr_file"
    if [ -n "$stderr" ]; then
      die "failed to list Claude Code plugins: $stderr"
    fi
    die "failed to list Claude Code plugins: $output"
  fi

  if parse_error="$(printf '%s\n' "$output" | json_array_contains_field_value "claude plugin list" "id" "$plugin" 2>&1)"; then
    return 0
  else
    status=$?
  fi

  [ "$status" -eq 1 ] && return 1
  die "$parse_error"
}

# Return the LeanCTX command Claude Desktop should launch. Prefer an absolute
# path because macOS GUI apps do not reliably inherit the user's shell PATH.
leanctx_command_for_desktop() {
  command -v lean-ctx 2>/dev/null || printf 'lean-ctx\n'
}

# Merge the local LeanCTX MCP server into Claude Desktop's config.
configure_claude_desktop_leanctx() {
  local config
  local backup
  local leanctx_command

  config="$(claude_desktop_config_path)"
  leanctx_command="$(leanctx_command_for_desktop)"
  if [ "$dry_run" = "1" ]; then
    status_dry_run "Configure LeanCTX for Claude Desktop $config"
    log_line "update_claude_desktop_config=$config server=lean-ctx command=$leanctx_command"
    return 0
  fi

  if [ -e "$config" ]; then
    backup="$(backup_path "$config")"
    status_ok "Backing up $config to $backup"
    mkdir -p "$(dirname "$config")"
    cp "$config" "$backup"
  fi

  mkdir -p "$(dirname "$config")"
  node - "$config" "$leanctx_command" <<'NODE'
const fs = require("fs");

const configPath = process.argv[2];
const leanctxCommand = process.argv[3];
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

config.mcpServers["lean-ctx"] = {
  command: leanctxCommand
};

fs.writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);
NODE
  status_ok "Configure LeanCTX for Claude Desktop $config"
  log_line "update_claude_desktop_config=$config server=lean-ctx command=$leanctx_command"
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

# Merge the local Context7 MCP server into VS Code's user MCP config without
# logging the raw API key.
configure_vscode_context7() {
  local config
  local backup

  config="$(vscode_mcp_config_path)"
  if [ "$dry_run" = "1" ]; then
    status_dry_run "Configure Context7 for VS Code $config"
    log_line "update_vscode_mcp_config=$config server=context7"
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
  throw new Error("VS Code MCP config must be a JSON object");
}

if (!config.servers || Array.isArray(config.servers) || typeof config.servers !== "object") {
  config.servers = {};
}

config.servers.context7 = {
  command: "npx",
  args: ["-y", "@upstash/context7-mcp"],
  env: {
    CONTEXT7_API_KEY: apiKey
  }
};

fs.writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);
NODE
  status_ok "Configure Context7 for VS Code $config"
  log_line "update_vscode_mcp_config=$config server=context7"
}

# Return the Git project directory LeanCTX setup should run from.
leanctx_find_git_project_under() {
  local base="$1"
  local candidate
  local root

  [ -d "$base" ] || return 0

  root="$(git_root_for "$base")"
  if [ -n "$root" ]; then
    printf '%s\n' "$root"
    return 0
  fi

  for candidate in "$base"/* "$base"/*/*; do
    [ -d "$candidate" ] || continue
    root="$(git_root_for "$candidate")"
    if [ -n "$root" ]; then
      printf '%s\n' "$root"
      return 0
    fi
  done
}

leanctx_setup_project_dir() {
  local candidate
  local root=""

  if [ -n "${TOKEN_SAVER_LEANCTX_SETUP_DIR:-}" ]; then
    root="$(git_root_for "$TOKEN_SAVER_LEANCTX_SETUP_DIR")"
    [ -n "$root" ] || die "LeanCTX setup directory is not inside a Git repository: $TOKEN_SAVER_LEANCTX_SETUP_DIR"
    printf '%s\n' "$root"
    return 0
  fi

  if [ -n "${repo_path:-}" ]; then
    root="$(git_root_for "$repo_path")"
    if [ -n "$root" ]; then
      printf '%s\n' "$root"
      return 0
    fi
  fi

  root="$(git_root_for "$PWD")"
  if [ -n "$root" ]; then
    printf '%s\n' "$root"
    return 0
  fi

  root="$(git_root_for "$ROOT")"
  if [ -n "$root" ]; then
    printf '%s\n' "$root"
    return 0
  fi

  for candidate in \
    "$HOME/Documents/git/ai-assistant-stack" \
    "$HOME/Documents/git/token-saver-setup" \
    "$HOME/Documents/git" \
    "$HOME/git" \
    "$HOME/src" \
    "$HOME/Projects" \
    "$HOME/Documents"; do
    root="$(leanctx_find_git_project_under "$candidate")"
    if [ -n "$root" ]; then
      printf '%s\n' "$root"
      return 0
    fi
  done

  die "LeanCTX setup requires an active Git project directory; run from inside a Git project or pass --repo"
}

# Run LeanCTX setup from an active Git project with this stack's unattended
# configuration choices, then return to the user's home directory.
configure_leanctx_setup() {
  local project_root

  project_root="$(leanctx_setup_project_dir)"
  log_line "leanctx_setup_project=$project_root"
  run_stack_command "Configure LeanCTX setup" sh -c 'set -e; cd "$1"; printf "y\nn\ny\nmax\ny\n" | lean-ctx setup; cd "$HOME"' sh "$project_root"
  run_stack_command "Disable LeanCTX path jail" lean-ctx config set path_jail false --yes
  run_stack_command "Run LeanCTX doctor --fix" lean-ctx doctor --fix

  if tool_enabled claude && claude_desktop_available; then
    configure_claude_desktop_leanctx
  elif tool_enabled claude; then
    status_skipped "Claude Desktop app not found; skipped Desktop LeanCTX MCP config"
  fi

  if [ "$claude_proxy_enabled" = "1" ]; then
    run_stack_command "Enable LeanCTX proxy" env ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" lean-ctx proxy enable
  elif target_enabled codex; then
    run_stack_command "Enable LeanCTX proxy" lean-ctx proxy enable
  else
    status_skipped "LeanCTX proxy not enabled for selected targets"
    log_line "leanctx_proxy=skipped"
  fi

  if target_enabled codex; then
    run_stack_command "Enable LeanCTX Codex ChatGPT proxy" lean-ctx proxy codex-chatgpt on
  fi
}

# Install LeanCTX when missing, then run upstream setup with the stack defaults.
install_leanctx() {
  step "Install LeanCTX"
  if command -v lean-ctx >/dev/null 2>&1; then
    status_ok "LeanCTX already installed"
    log_line "leanctx=present"
  else
    run_stack_command "Install LeanCTX" sh -c "curl -fsSL https://leanctx.com/install.sh | sh"
  fi

  if command -v lean-ctx >/dev/null 2>&1 || [ "$dry_run" = "1" ]; then
    configure_leanctx_setup
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

  if target_enabled vscode; then
    configure_vscode_context7
  fi
}

# Install Caveman support for each selected AI product and detected CLI surface.
install_caveman() {
  step "Install Caveman"
  if tool_enabled codex; then
    if codex_skill_installed caveman; then
      status_skipped "Caveman already installed for Codex"
    else
      run_stack_command "Install all Caveman skills for Codex" npx skills add JuliusBrussee/caveman --yes --global --agent codex
    fi
  fi

  if tool_enabled claude && claude_cli_available; then
    if claude_code_skill_installed caveman; then
      status_skipped "Caveman already installed for Claude Code"
    else
      run_stack_command "Install Caveman skills for Claude Code" npx skills add JuliusBrussee/caveman --yes --global --agent claude-code
    fi
  elif tool_enabled claude; then
    status_skipped "Claude Code CLI not found; skipped Caveman for Claude Code"
  fi
}

write_manual_superpowers_using_skill() {
  local file="$1"
  local tmp_file

  tmp_file="$(mktemp)"
  {
    printf '%s\n' '---'
    printf '%s\n' 'name: using-superpowers'
    printf '%s\n' 'description: Manual Superpowers workflow only. Use this skill only when the user explicitly requests Superpowers, names this skill, or an already-active Superpowers workflow requires it.'
    printf '%s\n' '---'
    printf '\n'
    printf '%s\n' '# Using Superpowers Manually'
    printf '\n'
    printf '%s\n' 'Superpowers is installed and available, but this stack does not invoke Superpowers skills automatically.'
    printf '\n'
    printf '%s\n' 'Invoke a Superpowers skill only when:'
    printf '\n'
    printf '%s\n' '- The user explicitly names or requests Superpowers.'
    printf '%s\n' '- The user explicitly names a specific Superpowers skill.'
    printf '%s\n' '- An already-active Superpowers workflow requires the next Superpowers skill.'
    printf '\n'
    printf '%s\n' 'Do not invoke Superpowers skills automatically for normal session startup, routine software development, code edits, debugging, planning, review, or verification.'
    printf '\n'
    printf '%s\n' 'Local `AGENTS.md` or `CLAUDE.md` manual-only instructions take precedence over upstream automatic activation guidance.'
  } > "$tmp_file"

  if cmp -s "$tmp_file" "$file"; then
    rm -f "$tmp_file"
    return 1
  fi

  mv "$tmp_file" "$file"
  return 0
}

limit_superpowers_skill_activation() {
  local root
  local list
  local file
  local tmp_file
  local found=0
  local changed=0
  local replacement

  replacement="description: Manual Superpowers workflow only. Use this skill only when the user explicitly requests Superpowers, names this skill, or an already-active Superpowers workflow requires it."

  if [ "$dry_run" = "1" ]; then
    status_dry_run "Limit Superpowers skills to manual invocation"
    log_line "superpowers_manual_activation=dry-run"
    return 0
  fi

  for root in "$HOME/.codex/plugins/cache" "$HOME/.claude/plugins/cache"; do
    [ -d "$root" ] || continue
    list="$(mktemp)"
    find "$root" -path '*/superpowers/*/skills/*/SKILL.md' -type f > "$list"
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      found=1
      case "$file" in
        */skills/using-superpowers/SKILL.md)
          if write_manual_superpowers_using_skill "$file"; then
            changed=1
            log_line "superpowers_manual_activation_file=$file"
          fi
          continue
          ;;
      esac

      if grep -q '^description: Manual Superpowers workflow only\.' "$file"; then
        continue
      fi

      tmp_file="$(mktemp)"
      awk -v replacement="$replacement" '
        NR == 1 && $0 == "---" { in_frontmatter = 1 }
        in_frontmatter && !replaced && /^description:/ {
          print replacement
          replaced = 1
          next
        }
        { print }
      ' "$file" > "$tmp_file"
      mv "$tmp_file" "$file"
      changed=1
      log_line "superpowers_manual_activation_file=$file"
    done < "$list"
    rm -f "$list"
  done

  if [ "$found" -eq 0 ]; then
    status_skipped "Superpowers skill metadata not found for manual activation"
  elif [ "$changed" -eq 0 ]; then
    status_skipped "Superpowers skills already manual-only"
  else
    status_ok "Limit Superpowers skills to manual invocation"
  fi
}

# Install Superpowers through each client's native plugin system.
install_superpowers() {
  step "Install Superpowers"
  if tool_enabled codex; then
    if codex_plugin_installed superpowers@openai-curated; then
      status_skipped "Superpowers already installed for Codex"
    else
      run_stack_command "Install Superpowers for Codex" codex plugin add superpowers@openai-curated
    fi
  fi

  if tool_enabled claude && claude_cli_available; then
    if claude_plugin_installed superpowers@claude-plugins-official; then
      status_skipped "Superpowers already installed for Claude Code"
    else
      run_stack_command "Install Superpowers for Claude Code" claude plugin install superpowers@claude-plugins-official --scope user
    fi
  elif tool_enabled claude; then
    status_skipped "Claude Code CLI not found; skipped Superpowers for Claude Code"
  fi

  limit_superpowers_skill_activation
}

# Run every stack-tool setup step in the required order.
install_stack_tools() {
  install_leanctx
  configure_context7
  install_caveman
  install_superpowers
}
