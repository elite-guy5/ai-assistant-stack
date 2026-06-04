#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
non_interactive=0
dry_run=0
overwrite="${OVERWRITE:-0}"
overwrite_global_instructions=0
overwrite_project_templates=0
uninstall=0
uninstall_components=""
project_scope="${PROJECT_SCOPE:-$HOME/Documents}"
install_rtk=""
install_caveman=""
rtk_agents="claude,codex"
rtk_mode="auto"
caveman_args=""
caveman_mode="ultra"
caveman_modes="lite,full,ultra,wenyan-lite,wenyan-full,wenyan-ultra"
manifest_path="${TOKEN_SAVER_MANIFEST:-$HOME/.agents/install_manifest.json}"
uninstall_active=0
uninstall_report_file=""
current_tool=""

usage() {
  cat <<'EOF'
Usage: bash scripts/install.sh [options]

Options:
  --non-interactive        Use defaults and do not prompt
  --dry-run                Print actions without changing files or installing tools
  --project-scope <path>   Project directory for project seeding instructions
  --overwrite              Replace existing managed files instead of skipping them
  --overwrite-global-instructions
                           Replace existing ~/.claude/CLAUDE.md and ~/.codex/AGENTS.md
  --overwrite-project-templates
                           Replace existing project instruction template files
  --uninstall              Remove selected installed components
  --uninstall-components <list>
                           Comma-separated uninstall components, or "all available"
                           Components: global-instructions, reset-global-instructions, project-instructions, project-templates, seeding, ignore-optimizer, rtk, caveman
  --skip-rtk               Do not install or initialize RTK
  --skip-caveman           Do not install Caveman
  --rtk-agents <list>      Comma-separated RTK agents to initialize (default: claude,codex)
  --rtk-mode <mode>        RTK setup mode: auto or manual (default: auto)
  --caveman-args <args>    Extra args passed to the Caveman installer
  --caveman-mode <mode>    Persistent Caveman default mode (default: ultra)
  --help                   Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --non-interactive) non_interactive=1 ;;
    --dry-run) dry_run=1 ;;
    --overwrite) overwrite=1 ;;
    --overwrite-global-instructions) overwrite_global_instructions=1 ;;
    --overwrite-project-templates) overwrite_project_templates=1 ;;
    --uninstall) uninstall=1 ;;
    --uninstall-components)
      [ "$#" -gt 1 ] || { printf 'missing value for --uninstall-components\n' >&2; exit 2; }
      uninstall_components="$2"
      shift
      ;;
    --uninstall-components=*) uninstall_components="${1#*=}" ;;
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
    --rtk-mode)
      [ "$#" -gt 1 ] || { printf 'missing value for --rtk-mode\n' >&2; exit 2; }
      rtk_mode="$2"
      shift
      ;;
    --rtk-mode=*) rtk_mode="${1#*=}" ;;
    --caveman-args)
      [ "$#" -gt 1 ] || { printf 'missing value for --caveman-args\n' >&2; exit 2; }
      caveman_args="$2"
      shift
      ;;
    --caveman-args=*) caveman_args="${1#*=}" ;;
    --caveman-mode)
      [ "$#" -gt 1 ] || { printf 'missing value for --caveman-mode\n' >&2; exit 2; }
      caveman_mode="$2"
      shift
      ;;
    --caveman-mode=*) caveman_mode="${1#*=}" ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [ ! -t 0 ] && [ ! -r /dev/tty ]; then
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

run_optional_uninstall_cmd() {
  local output status

  if [ "$dry_run" = "1" ]; then
    if [ "$uninstall_active" = "1" ]; then
      report_event "Skills and Plugins" "$current_tool" "Shell Commands Removed" "$*" "ok"
    else
      printf 'dry-run: %s\n' "$*"
    fi
    return 0
  fi
  output="$(mktemp)"
  if "$@" >"$output" 2>&1; then
    [ "$uninstall_active" = "1" ] && report_event "Skills and Plugins" "$current_tool" "Shell Commands Removed" "$*" "ok"
  else
    status=$?
    if [ "$uninstall_active" = "1" ]; then
      report_event "Verification" "$current_tool" "Verification Issues" "$* (exit $status)" "warn"
    else
      cat "$output" >&2
      printf 'warning: uninstall command failed: %s\n' "$*" >&2
    fi
  fi
  rm -f "$output"
}

record_manifest() {
  local type="$1"
  local component="$2"
  local ownership="$3"
  local action="$4"
  local path="$5"
  local details="${6:-{}}"

  if [ "$dry_run" = "1" ]; then
    printf 'dry-run: would record manifest artifact %s %s %s\n' "$component" "$type" "$path"
    return 0
  fi

  if ! command -v node >/dev/null 2>&1; then
    printf 'warning: node required to update install manifest; skipping manifest record for %s\n' "$path" >&2
    return 0
  fi

  mkdir -p "$(dirname "$manifest_path")"
  node - "$manifest_path" "$type" "$component" "$ownership" "$action" "$path" "$details" <<'NODE'
const fs = require("fs");
const [manifestPath, type, component, ownership, action, targetPath, detailsRaw] = process.argv.slice(2);
let details = {};
try { details = detailsRaw ? JSON.parse(detailsRaw) : {}; } catch { details = { raw: detailsRaw }; }
let manifest = { schemaVersion: 1, managedBy: "token-saver-setup", artifacts: [] };
if (fs.existsSync(manifestPath)) {
  const raw = fs.readFileSync(manifestPath, "utf8").trim();
  if (raw) manifest = JSON.parse(raw);
}
manifest.schemaVersion = 1;
manifest.managedBy = "token-saver-setup";
manifest.updatedAt = new Date().toISOString();
manifest.artifacts = Array.isArray(manifest.artifacts) ? manifest.artifacts : [];
const artifact = {
  id: [component, type, targetPath, details.key || details.command || ""].join(":"),
  type,
  component,
  ownership,
  action,
  path: targetPath,
  details,
  recordedAt: new Date().toISOString(),
};
const idx = manifest.artifacts.findIndex((item) => item.id === artifact.id);
if (idx >= 0) manifest.artifacts[idx] = artifact;
else manifest.artifacts.push(artifact);
fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n");
NODE
}

record_directory() {
  local target="$1"
  local component="$2"
  local ownership="$3"
  record_manifest "directory" "$component" "$ownership" "created-or-ensured" "$target"
}

prompt_yes_no() {
  local prompt="$1"
  local default="$2"
  local answer
  local default_label

  if [ "$non_interactive" = "1" ]; then
    [ "$default" = "yes" ] && return 0 || return 1
  fi

  if [ "$default" = "yes" ]; then
    default_label="y"
  else
    default_label="n"
  fi

  if [ -t 0 ]; then
    read -r -p "$prompt (y/n) [$default_label]: " answer
  elif [ -r /dev/tty ]; then
    printf '%s (y/n) [%s]: ' "$prompt" "$default_label" > /dev/tty
    read -r answer < /dev/tty
  else
    answer="$default"
  fi
  answer="${answer:-$default}"
  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    n|N|no|NO|No) return 1 ;;
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

  if [ -t 0 ]; then
    read -r -p "$prompt [$default]: " answer
  elif [ -r /dev/tty ]; then
    printf '%s [%s]: ' "$prompt" "$default" > /dev/tty
    read -r answer < /dev/tty
  else
    answer="$default"
  fi
  printf '%s\n' "${answer:-$default}"
}

validate_caveman_mode() {
  case "$1" in
    lite|full|ultra|wenyan-lite|wenyan-full|wenyan-ultra) return 0 ;;
    *)
      printf 'error: invalid Caveman mode: %s\n' "$1" >&2
      printf 'valid Caveman modes: %s\n' "$caveman_modes" >&2
      return 1
      ;;
  esac
}

copy_managed_file() {
  local source="$1"
  local target="$2"
  local component="${3:-managed-file}"
  local existed=0

  if [ "$dry_run" = "1" ]; then
    if [ ! -e "$target" ] || [ "$overwrite" = "1" ]; then
      printf 'dry-run: would install %s\n' "$target"
    elif cmp -s "$source" "$target"; then
      printf 'dry-run: already current %s\n' "$target"
    else
      printf 'dry-run: would skip existing managed file %s\n' "$target"
    fi
    return 0
  fi

  [ -e "$target" ] && existed=1
  mkdir -p "$(dirname "$target")"

  if [ ! -e "$target" ] || [ "$overwrite" = "1" ]; then
    record_directory "$(dirname "$target")" "$component" "installer-created"
    cp "$source" "$target"
    if [ "$existed" = "1" ]; then
      record_manifest "file" "$component" "user-owned" "modified" "$target"
    else
      record_manifest "file" "$component" "installer-created" "created" "$target"
    fi
    printf 'installed %s\n' "$target"
    return 0
  fi

  if cmp -s "$source" "$target"; then
    printf 'already current %s\n' "$target"
    return 0
  fi

  printf 'skipped existing managed file %s\n' "$target"
}

copy_global_instruction_file() {
  local source="$1"
  local target="$2"
  local existed=0

  if [ "$dry_run" = "1" ]; then
    if [ ! -e "$target" ]; then
      printf 'dry-run: would install %s\n' "$target"
    elif [ "$overwrite_global_instructions" = "1" ]; then
      printf 'dry-run: would overwrite %s\n' "$target"
    else
      printf 'dry-run: would skip existing global instruction file %s\n' "$target"
    fi
    return 0
  fi

  [ -e "$target" ] && existed=1
  mkdir -p "$(dirname "$target")"

  if [ ! -e "$target" ]; then
    record_directory "$(dirname "$target")" "global-instructions" "installer-created"
    cp "$source" "$target"
    record_manifest "global_instruction_file" "global-instructions" "installer-created" "created" "$target"
    printf 'installed %s\n' "$target"
    return 0
  fi

  if [ "$overwrite_global_instructions" = "1" ]; then
    record_directory "$(dirname "$target")" "global-instructions" "installer-created"
    cp "$source" "$target"
    if [ "$existed" = "1" ]; then
      record_manifest "global_instruction_file" "global-instructions" "user-owned" "modified" "$target"
    else
      record_manifest "global_instruction_file" "global-instructions" "installer-created" "created" "$target"
    fi
    printf 'overwrote %s\n' "$target"
    return 0
  fi

  printf 'skipped existing global instruction file %s\n' "$target"
}

copy_project_template_file() {
  local source="$1"
  local target="$2"
  local existed=0

  if [ "$dry_run" = "1" ]; then
    if [ ! -e "$target" ]; then
      printf 'dry-run: would install %s\n' "$target"
    elif [ "$overwrite_project_templates" = "1" ] || [ "$overwrite" = "1" ]; then
      printf 'dry-run: would overwrite %s\n' "$target"
    else
      printf 'dry-run: would skip existing project instruction template file %s\n' "$target"
    fi
    return 0
  fi

  [ -e "$target" ] && existed=1
  mkdir -p "$(dirname "$target")"

  if [ ! -e "$target" ]; then
    record_directory "$(dirname "$target")" "project-templates" "installer-created"
    cp "$source" "$target"
    record_manifest "project_template_file" "project-templates" "installer-created" "created" "$target"
    printf 'installed %s\n' "$target"
    return 0
  fi

  if [ "$overwrite_project_templates" = "1" ] || [ "$overwrite" = "1" ]; then
    record_directory "$(dirname "$target")" "project-templates" "installer-created"
    cp "$source" "$target"
    if [ "$existed" = "1" ]; then
      record_manifest "project_template_file" "project-templates" "user-owned" "modified" "$target"
    else
      record_manifest "project_template_file" "project-templates" "installer-created" "created" "$target"
    fi
    printf 'overwrote %s\n' "$target"
    return 0
  fi

  printf 'skipped existing project instruction template file %s\n' "$target"
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
  copy_managed_file "$temp" "$target" "seeding"
  rm -f "$temp"
}

render_global_instruction_template() {
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
  copy_global_instruction_file "$temp" "$target"
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
  record_manifest "settings_entry" "seeding" "user-owned" "ensured" "$settings_path" '{"key":"hooks.SessionStart","command":"seed-project-instructions.sh"}'
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
    cursor) printf '%s\n' "-g --agent cursor" ;;
    windsurf|cline|kilocode|antigravity|hermes|opencode|openclaw|pi) printf '%s\n' "--agent $1" ;;
    *) printf '%s\n' "--agent $1" ;;
  esac
}

csv_has_agent() {
  local list="$1"
  local wanted="$2"
  local old_ifs agent

  old_ifs="$IFS"
  IFS=","
  for agent in $list; do
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

append_agent_unique() {
  local agent="$1"

  csv_has_agent "$rtk_agents" "$agent" && return 0
  rtk_agents="${rtk_agents:+$rtk_agents,}$agent"
}

detect_command_or_dir() {
  local command_name="$1"
  shift

  if command -v "$command_name" >/dev/null 2>&1; then
    return 0
  fi

  while [ "$#" -gt 0 ]; do
    [ -e "$1" ] && return 0
    shift
  done

  return 1
}

detect_rtk_agents() {
  [ "$rtk_mode" = "auto" ] || return 0

  append_agent_unique claude
  detect_command_or_dir claude "$HOME/.claude" && append_agent_unique claude
  detect_command_or_dir codex "$HOME/.codex" && append_agent_unique codex
  detect_command_or_dir gemini "$HOME/.gemini" && append_agent_unique gemini
  detect_command_or_dir cursor "$HOME/.cursor" && append_agent_unique cursor
  detect_command_or_dir gh "$HOME/.vscode" "$HOME/.config/Code/User" && append_agent_unique copilot
  detect_command_or_dir opencode "$HOME/.config/opencode" && append_agent_unique opencode
  detect_command_or_dir openclaw "$HOME/.openclaw" && append_agent_unique openclaw
  detect_command_or_dir pi "$HOME/.pi" && append_agent_unique pi
  detect_command_or_dir hermes "$HOME/.hermes" && append_agent_unique hermes
  detect_command_or_dir cline "$HOME/.config/cline" "$HOME/.cline" && append_agent_unique cline
  detect_command_or_dir windsurf "$HOME/.windsurf" && append_agent_unique windsurf
  detect_command_or_dir kilocode "$HOME/.kilocode" && append_agent_unique kilocode
  detect_command_or_dir antigravity "$HOME/.agents/rules" && append_agent_unique antigravity

  return 0
}

initialize_rtk_agents() {
  local old_ifs agent args

  [ "$install_rtk" = "1" ] || return 0
  install_rtk_binary
  detect_rtk_agents

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
    record_manifest "generated_tool_reference" "rtk" "external" "initialized" "rtk" "{\"agent\":\"$agent\",\"command\":\"rtk init $args\"}"
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
    printf 'error: RTK setup verification failed; rerun with --overwrite-global-instructions or inspect existing global instruction files\n' >&2
    return 1
  fi

  say "verified RTK setup"
}

install_caveman_agent_fallbacks() {
  command -v gemini >/dev/null 2>&1 && run_cmd gemini extensions install https://github.com/JuliusBrussee/caveman
  detect_command_or_dir codex "$HOME/.codex" && run_cmd npx skills add JuliusBrussee/caveman -a codex
  detect_command_or_dir cursor "$HOME/.cursor" && run_cmd npx skills add JuliusBrussee/caveman -a cursor
  detect_command_or_dir windsurf "$HOME/.windsurf" && run_cmd npx skills add JuliusBrussee/caveman -a windsurf
  detect_command_or_dir cline "$HOME/.config/cline" "$HOME/.cline" && run_cmd npx skills add JuliusBrussee/caveman -a cline
  detect_command_or_dir antigravity "$HOME/.agents/rules" && run_cmd npx skills add JuliusBrussee/caveman -a antigravity

  return 0
}

install_caveman_tool() {
  local args

  [ "$install_caveman" = "1" ] || return 0

  if ! command -v npx >/dev/null 2>&1 && [ "$dry_run" != "1" ]; then
    printf 'warning: npx is required to install Caveman; skipping\n' >&2
    return 0
  fi

  if [ "$dry_run" = "1" ]; then
    say "dry-run: would write caveman default mode $caveman_mode"
  else
    mkdir -p "$HOME/.config/caveman"
    printf '{\n  "defaultMode": "%s"\n}\n' "$caveman_mode" > "$HOME/.config/caveman/config.json"
  fi

  args="$caveman_args"
  if ! printf '%s' "$args" | grep -q -- '--all'; then
    args="--all${args:+ $args}"
  fi
  if [ "$non_interactive" = "1" ] && ! printf '%s' "$args" | grep -q -- '--non-interactive'; then
    args="${args:+$args }--non-interactive"
  fi
  if [ "$dry_run" = "1" ] && ! printf '%s' "$args" | grep -q -- '--dry-run'; then
    args="${args:+$args }--dry-run"
  fi

  # shellcheck disable=SC2086
  run_cmd npx -y github:JuliusBrussee/caveman -- $args
  record_manifest "file" "caveman" "installer-created" "created-or-modified" "$HOME/.config/caveman/config.json"
  record_manifest "generated_tool_reference" "caveman" "external" "installed" "npx" "{\"command\":\"npx -y github:JuliusBrussee/caveman -- $args\"}"
  install_caveman_agent_fallbacks
}

component_selected() {
  local wanted="$1"
  local old_ifs component

  case "$uninstall_components" in
    ""|all|"all available"|"all-available") return 0 ;;
  esac

  old_ifs="$IFS"
  IFS="," 
  for component in $uninstall_components; do
    IFS="$old_ifs"
    component="$(printf '%s' "$component" | xargs)"
    if [ "$component" = "$wanted" ]; then
      IFS="$old_ifs"
      return 0
    fi
    IFS="," 
  done
  IFS="$old_ifs"
  return 1
}

prompt_uninstall_components() {
  local component selected=""

  if prompt_yes_no "Reset all instruction files?" "no"; then
    selected="reset-global-instructions,project-instructions"
  elif prompt_yes_no "Reset only project instruction sections?" "no"; then
    selected="project-instructions"
  else
    selected="global-instructions"
  fi

  for component in project-templates seeding ignore-optimizer rtk caveman; do
    if prompt_yes_no "Remove ${component//-/ }?" "no"; then
      selected="${selected:+$selected,}$component"
    fi
  done
  printf '%s' "$selected"
}

section_line() {
  printf '%s\n' "$1"
  printf '%*s\n' 50 "" | tr ' ' "${2:--}"
}

report_event() {
  local section="$1"
  local tool="$2"
  local category="$3"
  local item="$4"
  local status="${5:-ok}"

  [ -n "$uninstall_report_file" ] || return 0
  printf '%s\t%s\t%s\t%s\t%s\n' "$section" "$tool" "$category" "$item" "$status" >> "$uninstall_report_file"
}

report_preserved() {
  report_event "Preserved Files" "" "Files Preserved" "$1" "ok"
}

tool_for_component() {
  case "$1" in
    caveman) printf '%s\n' "Caveman" ;;
    rtk) printf '%s\n' "RTK" ;;
    ignore-optimizer) printf '%s\n' "Optimize-AI" ;;
    seeding) printf '%s\n' "Seed Project" ;;
    project-instructions) printf '%s\n' "Project Instructions" ;;
    reset-global-instructions) printf '%s\n' "Instruction Files" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

remove_template_path() {
  local target="$1"
  if [ "$dry_run" = "1" ]; then
    report_event "Templates" "" "Files Removed" "$target" "ok"
    return 0
  fi
  if [ -e "$target" ]; then
    rm -rf "$target"
    report_event "Templates" "" "Files Removed" "$target" "ok"
  fi
}

remove_template_glob() {
  local pattern="$1"
  local old_nullglob path

  old_nullglob="$(shopt -p nullglob || true)"
  shopt -s nullglob
  for path in $pattern; do
    remove_template_path "$path"
  done
  eval "$old_nullglob" 2>/dev/null || true
}

remove_project_instruction_sections() {
  local project file changed=0

  if [ ! -d "$project_scope" ]; then
    report_event "Verification" "Project Instructions" "Verification Issues" "$project_scope not found" "warn"
    return 0
  fi

  for project in "$project_scope"/*; do
    [ -d "$project" ] || continue
    case "$(basename "$project")" in .*) continue ;; esac
    for file in "$project/CLAUDE.md" "$project/AGENTS.md"; do
      [ -f "$file" ] || continue
      if [ "$dry_run" = "1" ]; then
        report_event "Instruction Files" "" "Files Updated" "Would remove managed project sections from $file" "ok"
        report_preserved "$file"
        changed=1
        continue
      fi
      command -v node >/dev/null 2>&1 || {
        report_event "Verification" "Project Instructions" "Verification Issues" "node not found; skipped $file" "warn"
        continue
      }
      if node - "$file" <<'NODE'
const fs = require("fs");
const file = process.argv[2];
const before = fs.readFileSync(file, "utf8");
let after = before;
for (const heading of ["Token-Saver File Boundaries", "Development Workflow"]) {
  const re = new RegExp(`\\n?## ${heading}\\n[\\s\\S]*?(?=\\n## |\\s*$)`, "g");
  after = after.replace(re, "\n");
}
after = after.replace(/\n{3,}/g, "\n\n").replace(/\s+$/g, "\n");
if (after !== before) {
  fs.writeFileSync(file, after);
  process.exit(0);
}
process.exit(1);
NODE
      then
        report_event "Instruction Files" "" "Files Updated" "Removed managed project sections from $file" "ok"
        report_preserved "$file"
        changed=1
      fi
    done
  done

  [ "$changed" = "1" ] || report_event "Instruction Files" "" "Files Updated" "No managed project instruction sections found" "ok"
}

reset_global_instruction_files() {
  local file
  for file in "$HOME/.claude/CLAUDE.md" "$HOME/.codex/AGENTS.md"; do
    if [ "$dry_run" = "1" ]; then
      report_event "Instruction Files" "" "Files Updated" "Would reset $file" "ok"
      report_preserved "$file"
      continue
    fi
    mkdir -p "$(dirname "$file")"
    : > "$file"
    report_event "Instruction Files" "" "Files Updated" "Reset $file" "ok"
    report_preserved "$file"
  done
}

report_uninstall_summary() {
  [ -s "$uninstall_report_file" ] || return 0
  if command -v node >/dev/null 2>&1; then
    node - "$uninstall_report_file" <<'NODE'
const fs = require("fs");
const file = process.argv[2];
const rows = fs.readFileSync(file, "utf8").trim().split(/\n/).filter(Boolean).map((line) => {
  const [section, tool, category, item, status] = line.split("\t");
  return { section, tool, category, item, status };
});
const symbol = (status) => status === "warn" ? "!" : "✓";
const printRule = (char = "-") => console.log(char.repeat(50));
const printSection = (name, char = "-") => { console.log(name); printRule(char); };
const unique = (items) => [...new Set(items.filter(Boolean))];
const suppressDescendants = (items) => {
  const sorted = unique(items).sort((a, b) => a.length - b.length);
  return sorted.filter((item, idx) => !sorted.slice(0, idx).some((parent) => item.startsWith(parent.replace(/\/$/, "") + "/")));
};
const printRows = (items) => {
  for (const row of items) console.log(`${symbol(row.status)} ${row.item}`);
};

const instruction = rows.filter((r) => r.section === "Instruction Files");
if (instruction.length) {
  printSection("Instruction Files");
  printRows(instruction);
  console.log("");
}

const toolRows = rows.filter((r) => r.section === "Skills and Plugins");
if (toolRows.length) {
  printSection("Skills and Plugins", "=");
  for (const tool of ["Caveman", "RTK", "Optimize-AI", "Seed Project"]) {
    const owned = toolRows.filter((r) => r.tool === tool);
    if (!owned.length) continue;
    console.log(tool);
    printRule("-");
    const removedDirs = suppressDescendants(owned.filter((r) => r.category === "Directories Removed").map((r) => r.item));
    for (const category of ["Directories Removed", "Files Removed", "Symlinks Removed", "Shell Commands Removed", "Aliases Removed", "PATH Entries Removed", "Environment Variables Removed", "Configuration Entries Removed"]) {
      let entries = owned.filter((r) => r.category === category);
      if (!entries.length) continue;
      if (category === "Directories Removed") {
        const suppressed = new Set(removedDirs);
        entries = entries.filter((r) => suppressed.has(r.item));
      } else if (category === "Files Removed") {
        entries = entries.filter((r) => !removedDirs.some((dir) => r.item.startsWith(dir.replace(/\/$/, "") + "/")));
      }
      console.log(`${category} (${unique(entries.map((r) => r.item)).length})`);
      for (const item of unique(entries.map((r) => r.item))) console.log(`✓ ${item}`);
    }
    console.log("Status");
    console.log("✓ Successfully Removed");
    console.log("");
  }
}

const templates = rows.filter((r) => r.section === "Templates");
if (templates.length) {
  printSection("Templates");
  printRows(templates);
  console.log("");
}

const config = rows.filter((r) => r.section === "Configuration");
if (config.length) {
  printSection("Configuration");
  printRows(config);
  console.log("");
}

const verificationRows = rows.filter((r) => r.section === "Verification");
const selectedTools = unique(toolRows.map((r) => r.tool));
if (selectedTools.length || verificationRows.length) {
  printSection("Verification", "=");
  for (const tool of selectedTools) {
    const issues = verificationRows.filter((r) => r.tool === tool);
    console.log(tool);
    if (!issues.length) {
      console.log("✓ No managed artifacts remain");
    } else {
      for (const issue of issues) {
        console.log("! Remaining Artifact");
        console.log("Path:");
        console.log(issue.item);
        console.log("Reason:");
        console.log("Managed artifact still exists after uninstall.");
      }
    }
  }
  console.log("");
}

const preserved = rows.filter((r) => r.section === "Preserved Files");
if (preserved.length) {
  printSection("Preserved Files");
  for (const item of unique(preserved.map((r) => r.item))) console.log(`✓ ${item}`);
  console.log("");
}

const count = (category) => unique(rows.filter((r) => r.category === category).map((r) => r.item)).length;
printSection("Summary");
console.log(`Tools Removed: ${selectedTools.length}`);
console.log(`Directories Removed: ${count("Directories Removed")}`);
console.log(`Files Removed: ${count("Files Removed")}`);
console.log(`Symlinks Removed: ${count("Symlinks Removed")}`);
console.log(`Shell Commands Removed: ${count("Shell Commands Removed")}`);
console.log(`Files Updated: ${count("Files Updated") + count("Configuration Entries Removed")}`);
console.log(`Files Preserved: ${count("Files Preserved")}`);
console.log(`Verification Issues: ${verificationRows.length}`);
NODE
  fi
}

remove_path() {
  local target="$1"
  local category="Files Removed"
  [ -d "$target" ] && category="Directories Removed"

  if [ "$dry_run" = "1" ]; then
    if [ "$uninstall_active" = "1" ]; then
      report_event "Skills and Plugins" "$current_tool" "$category" "$target" "ok"
    else
      printf 'dry-run: would remove %s\n' "$target"
    fi
    return 0
  fi

  if [ -e "$target" ]; then
    rm -rf "$target"
    if [ "$uninstall_active" = "1" ]; then
      report_event "Skills and Plugins" "$current_tool" "$category" "$target" "ok"
    else
      printf 'removed %s\n' "$target"
    fi
  else
    [ "$uninstall_active" = "1" ] || printf 'already absent %s\n' "$target"
  fi
}

remove_glob_paths() {
  local pattern="$1"
  local old_nullglob path

  old_nullglob="$(shopt -p nullglob || true)"
  shopt -s nullglob
  for path in $pattern; do
    remove_path "$path"
  done
  eval "$old_nullglob" 2>/dev/null || true
}

selected_components() {
  case "$uninstall_components" in
    ""|all|"all available"|"all-available")
      printf '%s\n' "global-instructions,reset-global-instructions,project-instructions,project-templates,seeding,ignore-optimizer,rtk,caveman"
      ;;
    *) printf '%s\n' "$uninstall_components" ;;
  esac
}

manifest_has_component() {
  local component="$1"
  [ -f "$manifest_path" ] || return 1
  command -v node >/dev/null 2>&1 || return 1
  node - "$manifest_path" "$component" <<'NODE'
const fs = require("fs");
const [manifestPath, component] = process.argv.slice(2);
try {
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  process.exit(Array.isArray(manifest.artifacts) && manifest.artifacts.some((item) => item.component === component) ? 0 : 1);
} catch {
  process.exit(1);
}
NODE
}

manifest_artifacts_for_component() {
  local component="$1"
  node - "$manifest_path" "$component" <<'NODE'
const fs = require("fs");
const [manifestPath, component] = process.argv.slice(2);
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
for (const item of manifest.artifacts || []) {
  if (item.component !== component) continue;
  const key = item.details && item.details.key ? item.details.key : "";
  const command = item.details && item.details.command ? item.details.command : "";
  console.log([item.type || "", item.ownership || "", item.path || "", key, command].join("\t"));
}
NODE
}

uninstall_manifest_component() {
  local component="$1"
  local type ownership target key command

  manifest_artifacts_for_component "$component" | while IFS="$(printf '\t')" read -r type ownership target key command; do
    case "$type" in
      file|global_instruction_file|project_template_file)
        if [ "$component" = "global-instructions" ]; then
          report_event "Instruction Files" "" "Files Updated" "Preserved $(basename "$target")" "ok"
          report_preserved "$target"
        elif [ "$ownership" = "installer-created" ]; then
          if [ "$component" = "project-templates" ]; then
            remove_template_path "$target"
          else
            current_tool="$(tool_for_component "$component")"
            remove_path "$target"
          fi
        else
          report_preserved "$target"
        fi
        ;;
      directory)
        :
        ;;
      settings_entry)
        case "$component" in
          seeding) remove_claude_seed_hook ;;
          caveman) remove_caveman_claude_settings ;;
        esac
        ;;
      generated_tool_reference)
        case "$component" in
          rtk) uninstall_rtk_components ;;
          caveman) uninstall_caveman_components ;;
        esac
        ;;
    esac
  done
}

remove_claude_seed_hook() {
  local settings_path="$HOME/.claude/settings.json"

  if [ "$dry_run" = "1" ]; then
    if [ "$uninstall_active" = "1" ]; then
      report_event "Skills and Plugins" "Seed Project" "Configuration Entries Removed" "$settings_path hooks.SessionStart" "ok"
    else
      printf 'dry-run: would remove token-saver SessionStart hooks from %s\n' "$settings_path"
    fi
    return 0
  fi

  [ -f "$settings_path" ] || return 0
  command -v node >/dev/null 2>&1 || { printf 'warning: node required to edit %s; skipping\n' "$settings_path" >&2; return 0; }

  node - "$settings_path" <<'NODE'
const fs = require("fs");
const settingsPath = process.argv[2];
const raw = fs.readFileSync(settingsPath, "utf8").trim();
const data = raw ? JSON.parse(raw) : {};
if (data.hooks && Array.isArray(data.hooks.SessionStart)) {
  data.hooks.SessionStart = data.hooks.SessionStart
    .map((entry) => ({
      ...entry,
      hooks: Array.isArray(entry.hooks)
        ? entry.hooks.filter((hook) => !String(hook && hook.command || "").includes("seed-project-instructions"))
        : entry.hooks,
    }))
    .filter((entry) => !Array.isArray(entry.hooks) || entry.hooks.length > 0);
}
fs.writeFileSync(settingsPath, JSON.stringify(data, null, 2) + "\n");
NODE
  report_event "Skills and Plugins" "Seed Project" "Configuration Entries Removed" "$settings_path hooks.SessionStart" "ok"
}

remove_caveman_claude_settings() {
  local settings_path="$HOME/.claude/settings.json"

  if [ "$dry_run" = "1" ]; then
    if [ "$uninstall_active" = "1" ]; then
      report_event "Skills and Plugins" "Caveman" "Configuration Entries Removed" "$settings_path Caveman entries" "ok"
    else
      printf 'dry-run: would remove Caveman entries from %s\n' "$settings_path"
    fi
    return 0
  fi

  [ -f "$settings_path" ] || return 0
  command -v node >/dev/null 2>&1 || { printf 'warning: node required to edit %s; skipping\n' "$settings_path" >&2; return 0; }

  node - "$settings_path" <<'NODE'
const fs = require("fs");
const settingsPath = process.argv[2];
const raw = fs.readFileSync(settingsPath, "utf8").trim();
const data = raw ? JSON.parse(raw) : {};
const hasCaveman = (value) => JSON.stringify(value || "").toLowerCase().includes("caveman");

if (data.hooks && typeof data.hooks === "object") {
  for (const key of Object.keys(data.hooks)) {
    if (Array.isArray(data.hooks[key])) {
      data.hooks[key] = data.hooks[key]
        .map((entry) => ({
          ...entry,
          hooks: Array.isArray(entry.hooks) ? entry.hooks.filter((hook) => !hasCaveman(hook)) : entry.hooks,
        }))
        .filter((entry) => !Array.isArray(entry.hooks) || entry.hooks.length > 0);
    }
  }
}
if (hasCaveman(data.statusLine)) delete data.statusLine;
for (const prop of ["mcpServers", "plugins", "enabledPlugins"]) {
  if (data[prop] && typeof data[prop] === "object") {
    for (const key of Object.keys(data[prop])) {
      if (key.toLowerCase().includes("caveman") || hasCaveman(data[prop][key])) delete data[prop][key];
    }
  }
}
fs.writeFileSync(settingsPath, JSON.stringify(data, null, 2) + "\n");
NODE
  report_event "Skills and Plugins" "Caveman" "Configuration Entries Removed" "$settings_path Caveman entries" "ok"
}

remove_caveman_codex_config() {
  local config_path="$HOME/.codex/config.toml"
  local temp skip=0 block=""

  if [ "$dry_run" = "1" ]; then
    if [ "$uninstall_active" = "1" ]; then
      report_event "Skills and Plugins" "Caveman" "Configuration Entries Removed" "$config_path Caveman entries" "ok"
    else
      printf 'dry-run: would remove known Caveman entries from %s\n' "$config_path"
    fi
    return 0
  fi

  [ -f "$config_path" ] || return 0
  temp="$(mktemp)"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "[mcp_servers.fs_shrunk]"|"[hooks.state./Users/burljohnson/.agents/skills/i-caveman/SKILL.md]"*)
        skip=1
        block="$line"
        continue
        ;;
      "["*)
        skip=0
        block=""
        ;;
    esac
    if [ "$skip" = "1" ]; then
      continue
    fi
    case "$line" in
      *caveman*|*Caveman*) continue ;;
    esac
    printf '%s\n' "$line" >> "$temp"
  done < "$config_path"
  mv "$temp" "$config_path"
  report_event "Skills and Plugins" "Caveman" "Configuration Entries Removed" "$config_path Caveman entries" "ok"
}

uninstall_rtk_components() {
  local old_ifs agent args

  current_tool="RTK"
  detect_rtk_agents
  if command -v rtk >/dev/null 2>&1 || [ "$dry_run" = "1" ]; then
    old_ifs="$IFS"
    IFS=","
    for agent in $rtk_agents; do
      IFS="$old_ifs"
      agent="$(printf '%s' "$agent" | tr -d '[:space:]')"
      [ -n "$agent" ] || continue
      args="$(rtk_init_arg "$agent")"
      # shellcheck disable=SC2086
      run_optional_uninstall_cmd rtk init --uninstall $args
      IFS=","
    done
    IFS="$old_ifs"
  else
    report_event "Verification" "RTK" "Verification Issues" "rtk command not found; skipped external uninstall" "warn"
  fi
  remove_path "$HOME/.codex/RTK.md"
  remove_path "$HOME/.claude/RTK.md"
  remove_path "$HOME/.agents/rules/antigravity-rtk-rules.md"
  remove_glob_paths "$HOME/.agents/rules/*rtk*"
}

uninstall_caveman_components() {
  local skill

  current_tool="Caveman"
  if command -v npx >/dev/null 2>&1 || [ "$dry_run" = "1" ]; then
    run_optional_uninstall_cmd npx -y github:JuliusBrussee/caveman -- --uninstall --non-interactive
    run_optional_uninstall_cmd npx skills remove JuliusBrussee/caveman --all
  else
    report_event "Verification" "Caveman" "Verification Issues" "npx not found; skipped external uninstall" "warn"
  fi
  if command -v gemini >/dev/null 2>&1 || [ "$dry_run" = "1" ]; then
    run_optional_uninstall_cmd gemini extensions uninstall caveman
  fi
  remove_path "$HOME/.config/caveman/config.json"
  remove_path "$HOME/.config/caveman"
  remove_path "$HOME/.claude/plugins/cache/caveman"
  remove_path "$HOME/.claude/plugins/marketplaces/caveman"
  for skill in caveman caveman-help caveman-review caveman-compress caveman-stats caveman-commit; do
    remove_path "$HOME/.agents/skills/$skill"
    remove_path "$HOME/.claude/skills/$skill"
  done
  remove_glob_paths "$HOME/.claude/projects/*caveman*"
  remove_caveman_claude_settings
  remove_caveman_codex_config
}

uninstall_selected_components() {
  local old_ifs component used_manifest=0

  if [ -z "$uninstall_components" ] && [ "$non_interactive" = "1" ]; then
    uninstall_components="all available"
  fi

  if [ ! -f "$manifest_path" ] || ! command -v node >/dev/null 2>&1; then
    report_event "Configuration" "" "Configuration Entries Removed" "Install manifest missing or unreadable; used legacy cleanup fallback" "warn"
    legacy_uninstall_selected_components
    return
  fi

  old_ifs="$IFS"
  IFS=","
  for component in $(selected_components); do
    IFS="$old_ifs"
    component="$(printf '%s' "$component" | xargs)"
    [ -n "$component" ] || continue
    current_tool="$(tool_for_component "$component")"
    if manifest_has_component "$component"; then
      used_manifest=1
      uninstall_manifest_component "$component"
    else
      report_event "Configuration" "" "Configuration Entries Removed" "Manifest missing $component records; used legacy fallback" "warn"
      uninstall_components="$component"
      legacy_uninstall_selected_components
    fi
    IFS=","
  done
  IFS="$old_ifs"
  [ "$used_manifest" = "1" ] && report_event "Configuration" "" "Configuration Entries Removed" "Used install manifest $manifest_path" "ok"
}

legacy_uninstall_selected_components() {
  if component_selected "global-instructions"; then
    report_event "Instruction Files" "" "Files Updated" "Preserved CLAUDE.md" "ok"
    report_event "Instruction Files" "" "Files Updated" "Preserved AGENTS.md" "ok"
    report_preserved "$HOME/.claude/CLAUDE.md"
    report_preserved "$HOME/.codex/AGENTS.md"
  fi
  if component_selected "reset-global-instructions"; then
    reset_global_instruction_files
  fi
  if component_selected "project-instructions"; then
    remove_project_instruction_sections
  fi
  if component_selected "project-templates"; then
    remove_template_path "$HOME/.claude/CLAUDE.project-template.md"
    remove_template_path "$HOME/.codex/AGENTS.project-template.md"
    remove_template_glob "$HOME/.claude/CLAUDE.project-template.md.new"
    remove_template_glob "$HOME/.codex/AGENTS.project-template.md.new"
  fi
  if component_selected "seeding"; then
    current_tool="Seed Project"
    remove_path "$HOME/.agents/scripts/seed-project-instructions.sh"
    remove_path "$HOME/.agents/scripts/seed-project-instructions.ps1"
    remove_glob_paths "$HOME/.agents/scripts/seed-project-instructions.sh.new"
    remove_glob_paths "$HOME/.agents/scripts/seed-project-instructions.ps1.new"
    remove_claude_seed_hook
  fi
  if component_selected "ignore-optimizer"; then
    current_tool="Optimize-AI"
    remove_path "$HOME/.agents/scripts/optimize-ai.sh"
    remove_path "$HOME/.agents/scripts/optimize-ai.ps1"
    remove_glob_paths "$HOME/.agents/scripts/optimize-ai.sh.new"
    remove_glob_paths "$HOME/.agents/scripts/optimize-ai.ps1.new"
  fi
  if component_selected "rtk"; then
    uninstall_rtk_components
  fi
  if component_selected "caveman"; then
    uninstall_caveman_components
  fi
}

if [ "$uninstall" = "1" ]; then
  uninstall_active=1
  uninstall_report_file="$(mktemp)"
  if [ -z "$uninstall_components" ] && [ "$non_interactive" = "0" ]; then
    uninstall_components="$(prompt_uninstall_components)"
  elif [ -z "$uninstall_components" ]; then
    uninstall_components="all available"
  fi
  uninstall_selected_components
  report_uninstall_summary
  rm -f "$uninstall_report_file"
  exit 0
fi

project_scope="$(prompt_text "Enter project directory for project seeding instructions" "$project_scope")"

if prompt_yes_no "Overwrite existing global Claude/Codex instruction files?" "no"; then
  overwrite_global_instructions=1
fi

if prompt_yes_no "Overwrite existing project instruction template files?" "no"; then
  overwrite_project_templates=1
fi

if [ -z "$install_rtk" ]; then
  if prompt_yes_no "Install and initialize RTK?" "yes"; then
    install_rtk=1
  else
    install_rtk=0
  fi
fi

if [ "$install_rtk" = "1" ]; then
  rtk_agents="$(prompt_text "RTK agents to initialize, comma-separated or 'all available'" "$rtk_agents")"
  case "$rtk_agents" in
    all|"all available"|"all-available")
      rtk_agents=""
      rtk_mode="auto"
      ;;
  esac
  rtk_mode="$(prompt_text "RTK setup mode" "$rtk_mode")"
fi

if [ -z "$install_caveman" ]; then
  if prompt_yes_no "Install Caveman?" "yes"; then
    install_caveman=1
  else
    install_caveman=0
  fi
fi

if [ "$install_caveman" = "1" ] && [ "$non_interactive" != "1" ]; then
  caveman_mode="$(prompt_text "Caveman mode to use ($caveman_modes)" "$caveman_mode")"
  caveman_args="$(prompt_text "Extra Caveman args (examples: --all, --minimal, --only claude, --no-hooks)" "$caveman_args")"
fi

if [ "$install_caveman" = "1" ]; then
  validate_caveman_mode "$caveman_mode"
fi

copy_global_instruction_file "$ROOT/templates/CLAUDE.global.md" "$HOME/.claude/CLAUDE.md"
render_global_instruction_template "$ROOT/templates/AGENTS.global.md" "$HOME/.codex/AGENTS.md"
copy_project_template_file "$ROOT/templates/CLAUDE.project-template.md" "$HOME/.claude/CLAUDE.project-template.md"
copy_project_template_file "$ROOT/templates/AGENTS.project-template.md" "$HOME/.codex/AGENTS.project-template.md"
copy_managed_file "$ROOT/scripts/optimize-ai.sh" "$HOME/.agents/scripts/optimize-ai.sh" "ignore-optimizer"
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
