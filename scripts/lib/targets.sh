#!/usr/bin/env bash

# Store target-mode selection globally so install.sh can derive tool behavior
# after parsing arguments or auto-detection.
targets=""
target_mode=0

# Read one prompt response, using /dev/tty when bootstrap itself was piped into
# bash and normal stdin has already been consumed.
read_prompt_value() {
  local var_name="$1"
  local value=""

  if [ "${TOKEN_SAVER_PROMPT_TTY:-0}" = "1" ] && [ -r /dev/tty ] && [ -w /dev/tty ]; then
    if IFS= read -r value 2>/dev/null < /dev/tty; then
      printf -v "$var_name" '%s' "$value"
      return 0
    fi
    value=""
  fi

  if IFS= read -r value; then
    printf -v "$var_name" '%s' "$value"
    return 0
  else
    value=""
  fi

  printf -v "$var_name" '%s' "$value"
}

# Normalize a comma-separated product target list, reject unknown targets, and
# remove duplicates while preserving selection order. Older surface-level names
# remain accepted as aliases for the product-level targets.
normalize_targets() {
  local raw="$1"
  local normalized=""
  local item
  local target
  local old_ifs="$IFS"

  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
  [ -n "$raw" ] || die "missing value for --targets"

  IFS=','
  for item in $raw; do
    case "$item" in
      codex|codex-desktop|codex-vscode) target=codex ;;
      claude|claude-desktop|claude-code|claude-vscode|claude-code-vscode) target=claude ;;
      vscode|vs-code|code|visual-studio-code) target=vscode ;;
      *) IFS="$old_ifs"; die "invalid --targets value: $item" ;;
    esac
    case ",$normalized," in
      *",$target,"*) ;;
      *) normalized="${normalized:+$normalized,}$target" ;;
    esac
  done
  IFS="$old_ifs"

  printf '%s\n' "$normalized"
}

# Return success when the normalized target list includes a product.
target_enabled() {
  case ",$targets," in
    *",$1,"*) return 0 ;;
    *) return 1 ;;
  esac
}

# Collapse selected product targets into the legacy tool selector used by
# instruction-file installation.
derive_tools_from_targets() {
  local has_codex=0
  local has_claude=0

  target_enabled codex && has_codex=1
  target_enabled claude && has_claude=1

  case "$has_codex:$has_claude" in
    1:1) printf 'both\n' ;;
    1:0) printf 'codex\n' ;;
    0:1) printf 'claude\n' ;;
    *) printf '\n' ;;
  esac
}

# Detect every installed AI tool this stack can configure. Tests can suppress
# app-bundle detection by setting the matching *_APP_PATH variable to a missing
# path.
auto_detect_targets() {
  local detected=""

  codex_available && detected="${detected:+$detected,}codex"
  if claude_cli_available || claude_desktop_available; then
    detected="${detected:+$detected,}claude"
  fi
  vscode_available && detected="${detected:+$detected,}vscode"

  [ -n "$detected" ] || die "no supported AI tools were detected; install Codex, Claude, VS Code, or use --tools for instruction-file-only setup"
  printf '%s\n' "$detected"
}

# Return the Claude Desktop app path when one is available. Tests can override
# detection with CLAUDE_DESKTOP_APP_PATH to keep host state isolated.
claude_desktop_app_path() {
  local path

  if [ -n "${CLAUDE_DESKTOP_APP_PATH:-}" ]; then
    [ -d "$CLAUDE_DESKTOP_APP_PATH" ] && printf '%s\n' "$CLAUDE_DESKTOP_APP_PATH"
    return 0
  fi

  for path in "$HOME/Applications/Claude.app" "/Applications/Claude.app"; do
    if [ -d "$path" ]; then
      printf '%s\n' "$path"
      return 0
    fi
  done
}

claude_desktop_available() {
  [ -n "$(claude_desktop_app_path)" ]
}

claude_desktop_config_path() {
  printf '%s\n' "${CLAUDE_DESKTOP_CONFIG_PATH:-$HOME/Library/Application Support/Claude/claude_desktop_config.json}"
}

claude_cli_available() {
  command -v claude >/dev/null 2>&1
}

codex_available() {
  command -v codex >/dev/null 2>&1
}

vscode_app_path() {
  local path

  if [ -n "${VSCODE_APP_PATH:-}" ]; then
    [ -d "$VSCODE_APP_PATH" ] && printf '%s\n' "$VSCODE_APP_PATH"
    return 0
  fi

  for path in "$HOME/Applications/Visual Studio Code.app" "/Applications/Visual Studio Code.app"; do
    if [ -d "$path" ]; then
      printf '%s\n' "$path"
      return 0
    fi
  done
}

vscode_available() {
  command -v code >/dev/null 2>&1 || [ -n "$(vscode_app_path)" ]
}

vscode_mcp_config_path() {
  printf '%s\n' "${VSCODE_MCP_CONFIG_PATH:-$HOME/Library/Application Support/Code/User/mcp.json}"
}
