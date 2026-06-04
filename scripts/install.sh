#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
non_interactive=0
dry_run=0
overwrite="${OVERWRITE:-0}"
project_scope="${PROJECT_SCOPE:-$HOME/Documents/git}"
install_rtk=""
install_caveman=""
rtk_agents="claude,codex"
caveman_args=""

usage() {
  cat <<'EOF'
Usage: bash scripts/install.sh [options]

Options:
  --non-interactive        Use defaults and do not prompt
  --dry-run                Print actions without changing files or installing tools
  --project-scope <path>   Default project root for instruction seeding
  --overwrite              Replace existing managed files instead of writing .new files
  --skip-rtk               Do not install or initialize RTK
  --skip-caveman           Do not install Caveman
  --rtk-agents <list>      Comma-separated RTK agents to initialize (default: claude,codex)
  --caveman-args <args>    Extra args passed to the Caveman installer
  --help                   Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --non-interactive) non_interactive=1 ;;
    --dry-run) dry_run=1 ;;
    --overwrite) overwrite=1 ;;
    --skip-rtk) install_rtk=0 ;;
    --skip-caveman) install_caveman=0 ;;
    --project-scope)
      [ "$#" -gt 1 ] || { printf 'missing value for --project-scope\n' >&2; exit 2; }
      project_scope="$2"
      shift
      ;;
    --project-scope=*) project_scope="${1#*=}" ;;
    --rtk-agents)
      [ "$#" -gt 1 ] || { printf 'missing value for --rtk-agents\n' >&2; exit 2; }
      rtk_agents="$2"
      shift
      ;;
    --rtk-agents=*) rtk_agents="${1#*=}" ;;
    --caveman-args)
      [ "$#" -gt 1 ] || { printf 'missing value for --caveman-args\n' >&2; exit 2; }
      caveman_args="$2"
      shift
      ;;
    --caveman-args=*) caveman_args="${1#*=}" ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [ ! -t 0 ]; then
  non_interactive=1
fi

say() {
  printf '%s\n' "$*"
}

run_cmd() {
  if [ "$dry_run" = "1" ]; then
    printf 'dry-run: %s\n' "$*"
    return 0
  fi
  "$@"
}

prompt_yes_no() {
  local prompt="$1"
  local default="$2"
  local answer

  if [ "$non_interactive" = "1" ]; then
    [ "$default" = "yes" ] && return 0 || return 1
  fi

  read -r -p "$prompt [$default]: " answer
  answer="${answer:-$default}"
  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

prompt_text() {
  local prompt="$1"
  local default="$2"
  local answer

  if [ "$non_interactive" = "1" ]; then
    printf '%s\n' "$default"
    return 0
  fi

  read -r -p "$prompt [$default]: " answer
  printf '%s\n' "${answer:-$default}"
}

project_scope="$(prompt_text "Project scope for instruction seeding" "$project_scope")"

if [ -z "$install_rtk" ]; then
  if prompt_yes_no "Install and initialize RTK?" "yes"; then
    install_rtk=1
  else
    install_rtk=0
  fi
fi

if [ "$install_rtk" = "1" ]; then
  rtk_agents="$(prompt_text "RTK agents to initialize, comma-separated" "$rtk_agents")"
fi

if [ -z "$install_caveman" ]; then
  if prompt_yes_no "Install Caveman?" "yes"; then
    install_caveman=1
  else
    install_caveman=0
  fi
fi

if [ "$install_caveman" = "1" ] && [ "$non_interactive" != "1" ]; then
  caveman_args="$(prompt_text "Extra Caveman args (examples: --all, --minimal, --only claude, --no-hooks)" "$caveman_args")"
fi

copy_managed_file() {
  local source="$1"
  local target="$2"

  if [ "$dry_run" = "1" ]; then
    if [ ! -e "$target" ] || [ "$overwrite" = "1" ]; then
      printf 'dry-run: would install %s\n' "$target"
    elif cmp -s "$source" "$target"; then
      printf 'dry-run: already current %s\n' "$target"
    else
      printf 'dry-run: would leave %s unchanged and write %s.new\n' "$target" "$target"
    fi
    return 0
  fi

  mkdir -p "$(dirname "$target")"

  if [ ! -e "$target" ] || [ "$overwrite" = "1" ]; then
    cp "$source" "$target"
    printf 'installed %s\n' "$target"
    return 0
  fi

  if cmp -s "$source" "$target"; then
    printf 'already current %s\n' "$target"
    return 0
  fi

  cp "$source" "$target.new"
  printf 'left existing %s unchanged; wrote %s.new\n' "$target" "$target"
}

render_template() {
  local source="$1"
  local target="$2"
  local temp home_replacement scope_replacement

  temp="$(mktemp)"
  home_replacement="$(printf '%s' "$HOME" | sed 's/[&/\]/\\&/g')"
  scope_replacement="$(printf '%s' "$project_scope" | sed 's/[&/\]/\\&/g')"
  sed \
    -e "s/{{HOME}}/$home_replacement/g" \
    -e "s/{{PROJECT_SCOPE}}/$scope_replacement/g" \
    "$source" > "$temp"
  copy_managed_file "$temp" "$target"
  rm -f "$temp"
}

merge_claude_session_hook() {
  local settings_path="$HOME/.claude/settings.json"

  if [ "$dry_run" = "1" ]; then
    printf 'dry-run: would ensure Claude SessionStart hook in %s\n' "$settings_path"
    return 0
  fi

  if ! command -v node >/dev/null 2>&1; then
    printf 'warning: node is required to merge %s; skipping hook merge\n' "$settings_path" >&2
    return 0
  fi

  mkdir -p "$(dirname "$settings_path")"
  node - "$settings_path" <<'NODE'
const fs = require("fs");
const path = require("path");

const settingsPath = process.argv[2];
const scriptPath = path.join(process.env.HOME, ".agents", "scripts", "seed-project-instructions.sh");
const command = `bash "${scriptPath}"`;
const hook = { type: "command", command, timeout: 5 };

let data = {};
if (fs.existsSync(settingsPath)) {
  const raw = fs.readFileSync(settingsPath, "utf8").trim();
  data = raw ? JSON.parse(raw) : {};
}

data.hooks = data.hooks || {};
data.hooks.SessionStart = Array.isArray(data.hooks.SessionStart)
  ? data.hooks.SessionStart
  : [];

const exists = data.hooks.SessionStart.some((entry) =>
  Array.isArray(entry.hooks) &&
  entry.hooks.some((existing) => {
    const existingCommand = existing && existing.command ? existing.command : "";
    return existingCommand === command ||
      (existingCommand.includes("seed-project-instructions.sh") &&
       existingCommand.includes(".agents/scripts"));
  })
);

if (exists) {
  console.log(`already has SessionStart hook in ${settingsPath}`);
} else {
  data.hooks.SessionStart.push({ hooks: [hook] });
  fs.writeFileSync(settingsPath, JSON.stringify(data, null, 2) + "\n");
  console.log(`added SessionStart hook to ${settingsPath}`);
}
NODE
}

install_rtk_binary() {
  if command -v rtk >/dev/null 2>&1; then
    say "rtk already installed: $(command -v rtk)"
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    run_cmd brew install rtk
    return 0
  fi

  if command -v curl >/dev/null 2>&1; then
    if [ "$dry_run" = "1" ]; then
      say "dry-run: curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh"
    else
      curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
    fi
    return 0
  fi

  printf 'warning: could not install RTK; install curl or Homebrew and rerun\n' >&2
}

rtk_init_arg() {
  case "$1" in
    claude|"") printf '%s\n' "-g" ;;
    codex) printf '%s\n' "-g --codex" ;;
    gemini) printf '%s\n' "-g --gemini" ;;
    copilot) printf '%s\n' "-g --copilot" ;;
    cursor|windsurf|cline|kilocode|antigravity|hermes) printf '%s\n' "--agent $1" ;;
    *) printf '%s\n' "--agent $1" ;;
  esac
}

initialize_rtk_agents() {
  local old_ifs agent args

  [ "$install_rtk" = "1" ] || return 0
  install_rtk_binary

  if ! command -v rtk >/dev/null 2>&1 && [ "$dry_run" != "1" ]; then
    printf 'warning: rtk not found on PATH after install; skipping rtk init\n' >&2
    return 0
  fi

  old_ifs="$IFS"
  IFS=","
  for agent in $rtk_agents; do
    IFS="$old_ifs"
    agent="$(printf '%s' "$agent" | tr -d '[:space:]')"
    [ -n "$agent" ] || continue
    args="$(rtk_init_arg "$agent")"
    # shellcheck disable=SC2086
    run_cmd rtk init $args
    IFS=","
  done
  IFS="$old_ifs"
}

rtk_agent_enabled() {
  local wanted="$1"
  local old_ifs agent

  old_ifs="$IFS"
  IFS=","
  for agent in $rtk_agents; do
    IFS="$old_ifs"
    agent="$(printf '%s' "$agent" | tr -d '[:space:]')"
    if [ "$agent" = "$wanted" ]; then
      IFS="$old_ifs"
      return 0
    fi
    IFS=","
  done
  IFS="$old_ifs"
  return 1
}

require_file_contains() {
  local path="$1"
  local pattern="$2"
  local label="$3"

  if [ ! -f "$path" ]; then
    printf 'warning: missing %s: %s\n' "$label" "$path" >&2
    return 1
  fi

  if ! grep -Eq "$pattern" "$path"; then
    printf 'warning: %s does not contain required RTK rule: %s\n' "$label" "$path" >&2
    return 1
  fi

  return 0
}

verify_rtk_setup() {
  local failures=0

  [ "$install_rtk" = "1" ] || return 0

  if [ "$dry_run" = "1" ]; then
    say "dry-run: would verify RTK binary and assistant instruction wiring"
    return 0
  fi

  if ! command -v rtk >/dev/null 2>&1; then
    printf 'warning: rtk is not available on PATH after install/init\n' >&2
    failures=$((failures + 1))
  elif ! rtk --version >/dev/null 2>&1; then
    printf 'warning: rtk is installed but failed verification: rtk --version\n' >&2
    failures=$((failures + 1))
  fi

  if rtk_agent_enabled "codex"; then
    require_file_contains "$HOME/.codex/AGENTS.md" "RTK\\.md" "Codex AGENTS.md" || failures=$((failures + 1))
    require_file_contains "$HOME/.codex/RTK.md" 'Always prefix shell commands with `rtk`' "Codex RTK.md" || failures=$((failures + 1))
  fi

  if rtk_agent_enabled "claude"; then
    require_file_contains "$HOME/.claude/CLAUDE.md" "RTK\\.md" "Claude CLAUDE.md" || failures=$((failures + 1))
    require_file_contains "$HOME/.claude/RTK.md" "Always prefix shell commands|automatically rewritten|Hook-Based Usage" "Claude RTK.md" || failures=$((failures + 1))
  fi

  if [ "$failures" -gt 0 ]; then
    printf 'error: RTK setup verification failed; rerun with --overwrite or inspect the .new instruction files\n' >&2
    return 1
  fi

  say "verified RTK setup"
}

install_caveman_tool() {
  local args

  [ "$install_caveman" = "1" ] || return 0

  if ! command -v npx >/dev/null 2>&1 && [ "$dry_run" != "1" ]; then
    printf 'warning: npx is required to install Caveman; skipping\n' >&2
    return 0
  fi

  args="$caveman_args"
  if [ "$non_interactive" = "1" ] && ! printf '%s' "$args" | grep -q -- '--non-interactive'; then
    args="${args:+$args }--non-interactive"
  fi
  if [ "$dry_run" = "1" ] && ! printf '%s' "$args" | grep -q -- '--dry-run'; then
    args="${args:+$args }--dry-run"
  fi

  # shellcheck disable=SC2086
  run_cmd npx -y github:JuliusBrussee/caveman -- $args
}

copy_managed_file "$ROOT/templates/CLAUDE.global.md" "$HOME/.claude/CLAUDE.md"
render_template "$ROOT/templates/AGENTS.global.md" "$HOME/.codex/AGENTS.md"
copy_managed_file "$ROOT/templates/CLAUDE.project-template.md" "$HOME/.claude/CLAUDE.project-template.md"
copy_managed_file "$ROOT/templates/AGENTS.project-template.md" "$HOME/.codex/AGENTS.project-template.md"
copy_managed_file "$ROOT/scripts/optimize-ai.sh" "$HOME/.agents/scripts/optimize-ai.sh"
render_template "$ROOT/scripts/seed-project-instructions.sh" "$HOME/.agents/scripts/seed-project-instructions.sh"

if [ "$dry_run" != "1" ]; then
  chmod +x "$HOME/.agents/scripts/optimize-ai.sh"
  chmod +x "$HOME/.agents/scripts/seed-project-instructions.sh"
fi

merge_claude_session_hook
initialize_rtk_agents
verify_rtk_setup
install_caveman_tool

say "setup complete"
