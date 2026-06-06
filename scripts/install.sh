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
ai_apps="claude,codex"
assets="all"
rtk_agents="claude,codex"
rtk_mode="auto"
caveman_args=""
caveman_mode="ultra"
caveman_modes="lite,full,ultra,wenyan-lite,wenyan-full,wenyan-ultra"
allow_unverified_downloads=0
manifest_path="${TOKEN_SAVER_MANIFEST:-$HOME/.agents/install_manifest.json}"
uninstall_active=0
uninstall_report_file=""
install_active=0
install_report_file=""
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
  --ai-apps <list>         Comma-separated AI apps: claude,codex,gemini,cursor,opencode,openclaw,copilot,all
  --assets <list>          Comma-separated assets: rtk,caveman,global-instructions,project-instructions,ai-ignore-boundaries,all
  --rtk-agents <list>      Comma-separated RTK agents to initialize (default: claude,codex)
  --rtk-mode <mode>        RTK setup mode: auto or manual (default: auto)
  --caveman-args <args>    Extra args passed to the Caveman installer
  --caveman-mode <mode>    Persistent Caveman default mode (default: ultra)
  --allow-unverified-downloads
                           Permit legacy unpinned third-party RTK/Caveman remote installer fallbacks
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
    --ai-apps)
      [ "$#" -gt 1 ] || { printf 'missing value for --ai-apps\n' >&2; exit 2; }
      ai_apps="$2"
      shift
      ;;
    --ai-apps=*) ai_apps="${1#*=}" ;;
    --assets)
      [ "$#" -gt 1 ] || { printf 'missing value for --assets\n' >&2; exit 2; }
      assets="$2"
      shift
      ;;
    --assets=*) assets="${1#*=}" ;;
    --project-scope)
      [ "$#" -gt 1 ] || { printf 'missing value for --project-scope\n' >&2; exit 2; }
      project_scope="$2"
      shift
      ;;
    --project-scope=*) project_scope="${1#*=}" ;;
    --rtk-agents)
      [ "$#" -gt 1 ] || { printf 'missing value for --rtk-agents\n' >&2; exit 2; }
      rtk_agents="$2"
      ai_apps="$2"
      shift
      ;;
    --rtk-agents=*) rtk_agents="${1#*=}"; ai_apps="${1#*=}" ;;
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
    --allow-unverified-downloads) allow_unverified_downloads=1 ;;
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
  local status

  if [ "$dry_run" = "1" ]; then
    if [ "$install_active" = "1" ]; then
      install_event "Skills and Plugins" "$current_tool" "Shell Commands Run" "dry-run: $*" "ok"
    else
      printf 'dry-run: %s\n' "$*"
    fi
    return 0
  fi
  if "$@"; then
    :
  else
    status=$?
    printf 'error: %s failed with exit code %s: %s\n' "${current_tool:-command}" "$status" "$*" >&2
    return "$status"
  fi
  if [ "$install_active" = "1" ]; then
    install_event "Skills and Plugins" "$current_tool" "Shell Commands Run" "$*" "ok"
  fi
}

run_interactive_cmd() {
  local status

  if [ "$dry_run" = "1" ]; then
    if [ "$install_active" = "1" ]; then
      install_event "Skills and Plugins" "$current_tool" "Shell Commands Run" "dry-run: $*" "ok"
    else
      printf 'dry-run: %s\n' "$*"
    fi
    return 0
  fi

  if [ "$non_interactive" = "1" ]; then
    run_cmd "$@"
    return $?
  fi

  # Prefer inheriting the current terminal directly. Some packaged CLIs, including
  # Bun-based Claude commands, fail when stdout/stderr are reopened against /dev/tty.
  if [ -t 0 ] && [ -t 1 ] && [ -t 2 ]; then
    if "$@"; then
      :
    else
      status=$?
      stty sane >/dev/null 2>&1 || true
      printf 'error: %s failed with exit code %s: %s\n' "${current_tool:-command}" "$status" "$*" >&2
      return "$status"
    fi
  elif [ -r /dev/tty ]; then
    if "$@" </dev/tty; then
      :
    else
      status=$?
      stty sane </dev/tty >/dev/null 2>&1 || true
      printf 'error: %s failed with exit code %s: %s\n' "${current_tool:-command}" "$status" "$*" >&2
      return "$status"
    fi
  else
    run_cmd "$@"
    return $?
  fi

  stty sane >/dev/null 2>&1 || true
  if [ "$install_active" = "1" ]; then
    install_event "Skills and Plugins" "$current_tool" "Shell Commands Run" "$*" "ok"
  fi
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
    if [ "$install_active" = "1" ]; then
      install_event "Configuration" "" "Configuration Entries Updated" "dry-run: would record manifest artifact $component $type $path" "ok"
    else
      printf 'dry-run: would record manifest artifact %s %s %s\n' "$component" "$type" "$path"
    fi
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
const parseDetails = (raw) => {
  if (!raw) return {};
  let candidate = raw;
  while (candidate) {
    try { return JSON.parse(candidate); } catch {}
    if (!candidate.endsWith("}")) break;
    candidate = candidate.slice(0, -1);
  }
  return { raw };
};
let details = parseDetails(detailsRaw);
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

normalize_ai_app() {
  local app="$1"

  app="$(printf '%s' "$app" | tr '[:upper:]_' '[:lower:]-' | xargs)"
  app="$(printf '%s' "$app" | sed 's/[[:space:]]\+/-/g')"
  case "$app" in
    claude|claude-code|claudecode) printf '%s\n' "claude" ;;
    codex|gemini|cursor|opencode|openclaw|copilot) printf '%s\n' "$app" ;;
    github-copilot|githubcopilot) printf '%s\n' "copilot" ;;
    *) printf 'error: unsupported AI app: %s\n' "$1" >&2; return 1 ;;
  esac
}

normalize_ai_apps() {
  local input="$1"
  local old_ifs item normalized result=""

  case "$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]' | xargs)" in
    all|"all available"|"all-available")
      printf '%s\n' "claude,codex,gemini,cursor,opencode,openclaw,copilot"
      return 0
      ;;
  esac

  old_ifs="$IFS"
  IFS=","
  for item in $input; do
    IFS="$old_ifs"
    item="$(printf '%s' "$item" | xargs)"
    [ -n "$item" ] || { IFS=","; continue; }
    normalized="$(normalize_ai_app "$item")"
    csv_has_agent "$result" "$normalized" || result="${result:+$result,}$normalized"
    IFS=","
  done
  IFS="$old_ifs"

  [ -n "$result" ] || result="claude,codex"
  printf '%s\n' "$result"
}

normalize_asset() {
  local asset="$1"

  asset="$(printf '%s' "$asset" | tr '[:upper:]_' '[:lower:]-' | xargs)"
  asset="$(printf '%s' "$asset" | sed 's/[[:space:]]\+/-/g')"
  case "$asset" in
    rtk|caveman|global-instructions|project-instructions|ai-ignore-boundaries) printf '%s\n' "$asset" ;;
    global|global-instruction-files) printf '%s\n' "global-instructions" ;;
    project|project-instruction-files|project-templates|seeding) printf '%s\n' "project-instructions" ;;
    ignore|ignore-boundaries|ignore-optimizer|ai-ignore) printf '%s\n' "ai-ignore-boundaries" ;;
    *) printf 'error: unsupported asset: %s\n' "$1" >&2; return 1 ;;
  esac
}

normalize_assets() {
  local input="$1"
  local old_ifs item normalized result=""

  case "$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]' | xargs)" in
    all|"all available"|"all-available")
      printf '%s\n' "rtk,caveman,global-instructions,project-instructions,ai-ignore-boundaries"
      return 0
      ;;
  esac

  old_ifs="$IFS"
  IFS=","
  for item in $input; do
    IFS="$old_ifs"
    item="$(printf '%s' "$item" | xargs)"
    [ -n "$item" ] || { IFS=","; continue; }
    normalized="$(normalize_asset "$item")"
    csv_has_agent "$result" "$normalized" || result="${result:+$result,}$normalized"
    IFS=","
  done
  IFS="$old_ifs"

  [ -n "$result" ] || result="rtk,caveman,global-instructions,project-instructions,ai-ignore-boundaries"
  printf '%s\n' "$result"
}

app_selected() {
  csv_has_agent "$ai_apps" "$1"
}

asset_selected() {
  csv_has_agent "$assets" "$1"
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
      install_file_event "$component" "Files Installed" "dry-run: would install $target"
    elif cmp -s "$source" "$target"; then
      install_file_event "$component" "Files Already Current" "dry-run: already current $target"
    else
      install_file_event "$component" "Files Skipped" "dry-run: would skip existing managed file $target"
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
    install_file_event "$component" "Files Installed" "installed $target"
    return 0
  fi

  if cmp -s "$source" "$target"; then
    install_file_event "$component" "Files Already Current" "already current $target"
    return 0
  fi

  install_file_event "$component" "Files Skipped" "skipped existing managed file $target"
}

copy_global_instruction_file() {
  local source="$1"
  local target="$2"
  local existed=0

  if [ "$dry_run" = "1" ]; then
    if [ ! -e "$target" ]; then
      install_file_event "global-instructions" "Files Installed" "dry-run: would install $target"
    elif [ "$overwrite_global_instructions" = "1" ]; then
      install_file_event "global-instructions" "Files Overwritten" "dry-run: would overwrite $target"
    else
      install_file_event "global-instructions" "Files Skipped" "dry-run: would skip existing global instruction file $target"
    fi
    return 0
  fi

  [ -e "$target" ] && existed=1
  mkdir -p "$(dirname "$target")"

  if [ ! -e "$target" ]; then
    record_directory "$(dirname "$target")" "global-instructions" "installer-created"
    cp "$source" "$target"
    record_manifest "global_instruction_file" "global-instructions" "installer-created" "created" "$target"
    install_file_event "global-instructions" "Files Installed" "installed $target"
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
    install_file_event "global-instructions" "Files Overwritten" "overwrote $target"
    return 0
  fi

  install_file_event "global-instructions" "Files Skipped" "skipped existing global instruction file $target"
}

copy_project_template_file() {
  local source="$1"
  local target="$2"
  local existed=0

  if [ "$dry_run" = "1" ]; then
    if [ ! -e "$target" ]; then
      install_file_event "project-templates" "Files Installed" "dry-run: would install $target"
    elif [ "$overwrite_project_templates" = "1" ] || [ "$overwrite" = "1" ]; then
      install_file_event "project-templates" "Files Overwritten" "dry-run: would overwrite $target"
    else
      install_file_event "project-templates" "Files Skipped" "dry-run: would skip existing project instruction template file $target"
    fi
    return 0
  fi

  [ -e "$target" ] && existed=1
  mkdir -p "$(dirname "$target")"

  if [ ! -e "$target" ]; then
    record_directory "$(dirname "$target")" "project-templates" "installer-created"
    cp "$source" "$target"
    record_manifest "project_template_file" "project-templates" "installer-created" "created" "$target"
    install_file_event "project-templates" "Files Installed" "installed $target"
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
    install_file_event "project-templates" "Files Overwritten" "overwrote $target"
    return 0
  fi

  install_file_event "project-templates" "Files Skipped" "skipped existing project instruction template file $target"
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
  local action

  if [ "$dry_run" = "1" ]; then
    install_event "Skills and Plugins" "Seed Project" "Configuration Entries Updated" "dry-run: would ensure Claude SessionStart hook in $settings_path" "ok"
    return 0
  fi

  if ! command -v node >/dev/null 2>&1; then
    printf 'warning: node is required to merge %s; skipping hook merge\n' "$settings_path" >&2
    return 0
  fi

  mkdir -p "$(dirname "$settings_path")"
  action="$(
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
  fs.copyFileSync(settingsPath, `${settingsPath}.bak`);
  try {
    data = raw ? JSON.parse(raw) : {};
  } catch (error) {
    console.error(`error: invalid JSON in ${settingsPath}; backup created at ${settingsPath}.bak`);
    process.exit(1);
  }
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
  const tmp = `${settingsPath}.tmp.${process.pid}`;
  const output = JSON.stringify(data, null, 2) + "\n";
  JSON.parse(output);
  fs.writeFileSync(tmp, output, { mode: fs.existsSync(settingsPath) ? fs.statSync(settingsPath).mode : 0o600 });
  fs.renameSync(tmp, settingsPath);
  console.log(`added SessionStart hook to ${settingsPath}`);
}
NODE
  )"
  install_event "Skills and Plugins" "Seed Project" "Configuration Entries Updated" "$action" "ok"
  record_manifest "settings_entry" "seeding" "user-owned" "ensured" "$settings_path" '{"key":"hooks.SessionStart","command":"seed-project-instructions.sh"}'
}

ensure_rtk_claude_hook() {
  local settings_path="$HOME/.claude/settings.json"
  local action

  [ "$install_rtk" = "1" ] || return 0
  rtk_agent_enabled "claude" || return 0

  if [ "$dry_run" = "1" ]; then
    install_event "Skills and Plugins" "RTK" "Configuration Entries Updated" "dry-run: would ensure RTK Claude hook in $settings_path" "ok"
    record_manifest "settings_entry" "rtk" "user-owned" "added" "$settings_path" '{"key":"hooks.PreToolUse","command":"rtk hook claude","managedEntry":"RTK Claude hook","uninstallBehavior":"remove only the RTK hook entry, preserve the file"}'
    return 0
  fi

  if ! command -v node >/dev/null 2>&1; then
    printf 'error: node is required to patch %s for RTK Claude hook\n' "$settings_path" >&2
    return 1
  fi

  mkdir -p "$(dirname "$settings_path")"
  action="$(
    node - "$settings_path" <<'NODE'
const fs = require("fs");
const settingsPath = process.argv[2];
const command = "rtk hook claude";
const hook = { type: "command", command };
const backupPath = `${settingsPath}.bak`;
const existed = fs.existsSync(settingsPath);
let data = {};

if (existed) {
  fs.copyFileSync(settingsPath, backupPath);
  const raw = fs.readFileSync(settingsPath, "utf8").trim();
  try {
    data = raw ? JSON.parse(raw) : {};
  } catch (error) {
    console.error(`error: invalid JSON in ${settingsPath}; backup created at ${backupPath}`);
    process.exit(2);
  }
}

if (!data || typeof data !== "object" || Array.isArray(data)) data = {};
if (!data.hooks || typeof data.hooks !== "object" || Array.isArray(data.hooks)) data.hooks = {};
if (!Array.isArray(data.hooks.PreToolUse)) data.hooks.PreToolUse = [];

let bashEntry = data.hooks.PreToolUse.find((entry) => entry && entry.matcher === "Bash");
const alreadyExists = data.hooks.PreToolUse.some((entry) =>
  Array.isArray(entry && entry.hooks) &&
  entry.hooks.some((existing) => existing && existing.type === "command" && existing.command === command)
);

if (alreadyExists) {
  console.log("already_existed");
  process.exit(0);
}

if (!bashEntry) {
  bashEntry = { matcher: "Bash", hooks: [] };
  data.hooks.PreToolUse.push(bashEntry);
}
if (!Array.isArray(bashEntry.hooks)) bashEntry.hooks = [];
bashEntry.hooks.push(hook);

const output = JSON.stringify(data, null, 2) + "\n";
JSON.parse(output);
const tmp = `${settingsPath}.tmp.${process.pid}`;
fs.writeFileSync(tmp, output, { mode: existed ? fs.statSync(settingsPath).mode : 0o600 });
fs.renameSync(tmp, settingsPath);
console.log("added");
NODE
  )" || return 1

  case "$action" in
    already_existed)
      install_event "Skills and Plugins" "RTK" "Configuration Entries Updated" "already configured RTK Claude hook in $settings_path" "ok"
      record_manifest "settings_entry" "rtk" "user-owned" "already_existed" "$settings_path" '{"key":"hooks.PreToolUse","command":"rtk hook claude","managedEntry":"RTK Claude hook","uninstallBehavior":"remove only the RTK hook entry, preserve the file"}'
      ;;
    added)
      install_event "Skills and Plugins" "RTK" "Configuration Entries Updated" "Registered Claude Code hook" "ok"
      install_event "Skills and Plugins" "RTK" "Configuration Entries Updated" "Updated $settings_path" "ok"
      record_manifest "settings_entry" "rtk" "user-owned" "added" "$settings_path" '{"key":"hooks.PreToolUse","command":"rtk hook claude","managedEntry":"RTK Claude hook","uninstallBehavior":"remove only the RTK hook entry, preserve the file"}'
      ;;
    *)
      printf 'error: unexpected RTK Claude hook action: %s\n' "$action" >&2
      return 1
      ;;
  esac
}

find_rtk_config_path() {
  local candidates=(
    "$HOME/.config/rtk/rtk.toml"
    "$HOME/.config/rtk/config.toml"
    "$HOME/.rtk/rtk.toml"
    "$HOME/.rtk/config.toml"
  )
  local candidate

  for candidate in "${candidates[@]}"; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  printf '%s\n' "$HOME/.config/rtk/rtk.toml"
}

ensure_rtk_telemetry_disabled() {
  local config_path action original_value section_created
  config_path="$(find_rtk_config_path)"

  if [ "$dry_run" = "1" ]; then
    install_event "Skills and Plugins" "RTK" "Configuration Entries Updated" "dry-run: would ensure RTK telemetry disabled in $config_path" "ok"
    return 0
  fi

  mkdir -p "$(dirname "$config_path")"
  action="$(
    node - "$config_path" <<'NODE'
const fs = require('fs');
const configPath = process.argv[2];
const raw = fs.existsSync(configPath) ? fs.readFileSync(configPath, 'utf8').replace(/\r/g, '') : '';
const lines = raw === '' ? [] : raw.split('\n');
let inTelemetry = false;
let telemetryFound = false;
let enabledFound = false;
let originalValue = '';
let sectionCreated = false;
const output = [];

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  const trimmed = line.trim();
  if (/^\[.*\]$/.test(trimmed)) {
    if (inTelemetry && !enabledFound) {
      output.push('enabled = false');
      enabledFound = true;
    }
    inTelemetry = trimmed === '[telemetry]';
    if (inTelemetry) telemetryFound = true;
    output.push(line);
    continue;
  }
  if (inTelemetry) {
    const m = trimmed.match(/^enabled\s*=\s*(.*)$/);
    if (m) {
      originalValue = m[1].trim();
      if (originalValue === 'false') {
        output.push(line);
        enabledFound = true;
        continue;
      }
      output.push('enabled = false');
      enabledFound = true;
      continue;
    }
  }
  output.push(line);
}

if (!telemetryFound) {
  if (output.length && output[output.length - 1] !== '') output.push('');
  output.push('[telemetry]');
  output.push('enabled = false');
  sectionCreated = true;
} else if (!enabledFound) {
  output.push('enabled = false');
}

fs.writeFileSync(configPath, (output.join('\n') + '\n'), { mode: fs.existsSync(configPath) ? fs.statSync(configPath).mode : 0o600 });
const action = telemetryFound && enabledFound && originalValue === 'false' ? 'already_disabled' : (raw === '' ? 'created' : 'updated');
process.stdout.write(`${action}\t${originalValue}\t${sectionCreated ? '1' : '0'}`);
NODE
  )"

  original_value="$(printf '%s' "$action" | cut -f2)"
  section_created="$(printf '%s' "$action" | cut -f3)"
  action="$(printf '%s' "$action" | cut -f1)"

  case "$action" in
    created)
      install_event "Skills and Plugins" "RTK" "Configuration Entries Updated" "Created RTK config with telemetry disabled at $config_path" "ok"
      record_manifest "file" "rtk" "installer-created" "created" "$config_path"
      ;;
    updated)
      install_event "Skills and Plugins" "RTK" "Configuration Entries Updated" "Disabled RTK telemetry in $config_path" "ok"
      record_manifest "settings_entry" "rtk" "user-owned" "modified" "$config_path" "{\"key\":\"telemetry.enabled\",\"originalValue\":\"$original_value\",\"createdSection\":$section_created}"
      ;;
    already_disabled)
      install_event "Skills and Plugins" "RTK" "Configuration Entries Updated" "Telemetry already disabled in $config_path" "ok"
      ;;
    *)
      install_event "Skills and Plugins" "RTK" "Configuration Entries Updated" "Ensured RTK telemetry disabled in $config_path" "ok"
      ;;
  esac
}

find_shell_profile_path() {
  local candidates=(
    "$HOME/.zshrc"
    "$HOME/.bashrc"
    "$HOME/.bash_profile"
    "$HOME/.profile"
  )
  local candidate

  for candidate in "${candidates[@]}"; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  printf '%s\n' "$HOME/.profile"
}

ensure_rtk_telemetry_shell_env() {
  local profile_path start_marker end_marker
  profile_path="$(find_shell_profile_path)"
  start_marker="# token-saver-setup managed RTK telemetry start"
  end_marker="# token-saver-setup managed RTK telemetry end"

  if [ "$dry_run" = "1" ]; then
    install_event "Skills and Plugins" "RTK" "Configuration Entries Updated" "dry-run: would ensure RTK_TELEMETRY_DISABLED=1 is present in $profile_path" "ok"
    return 0
  fi

  mkdir -p "$(dirname "$profile_path")"
  if [ ! -e "$profile_path" ]; then
    : > "$profile_path"
  fi

  if grep -Fq "$start_marker" "$profile_path"; then
    install_event "Skills and Plugins" "RTK" "Configuration Entries Updated" "RTK shell telemetry env already present in $profile_path" "ok"
    return 0
  fi

  printf '%s\n%s\n%s\n' "$start_marker" 'export RTK_TELEMETRY_DISABLED=1' "$end_marker" >> "$profile_path"
  install_event "Skills and Plugins" "RTK" "Configuration Entries Updated" "Added managed RTK telemetry shell env to $profile_path" "ok"
  record_manifest "settings_entry" "rtk" "user-owned" "added" "$profile_path" '{"key":"shell.RTK_TELEMETRY_DISABLED"}'
}

remove_rtk_telemetry_config() {
  local config_path="$1"
  local original_value="$2"

  if [ "$dry_run" = "1" ]; then
    report_event "Skills and Plugins" "RTK" "Configuration Entries Removed" "dry-run: would remove managed telemetry setting from $config_path" "ok"
    return 0
  fi

  [ -f "$config_path" ] || return 0
  node - "$config_path" "$original_value" <<'NODE'
const fs = require('fs');
const configPath = process.argv[2];
const originalValue = process.argv[3];
const raw = fs.readFileSync(configPath, 'utf8').replace(/\r/g, '');
const lines = raw.split('\n');
const blocks = [];
let current = { header: null, body: [] };
for (const line of lines) {
  const trimmed = line.trim();
  if (/^\[.*\]$/.test(trimmed)) {
    blocks.push(current);
    current = { header: line, body: [] };
    continue;
  }
  current.body.push(line);
}
blocks.push(current);
const output = [];
for (const block of blocks) {
  if (!block.header) {
    for (const line of block.body) output.push(line);
    continue;
  }
  if (block.header.trim() === '[telemetry]') {
    const filtered = block.body.filter((line) => !/^\s*enabled\s*=/.test(line));
    if (originalValue) {
      filtered.unshift(`enabled = ${originalValue}`);
    }
    if (filtered.length === 0) {
      continue;
    }
    output.push(block.header);
    for (const line of filtered) output.push(line);
    continue;
  }
  output.push(block.header);
  for (const line of block.body) output.push(line);
}
let cleaned = output.join('\n').replace(/\n{3,}/g, '\n\n');
fs.writeFileSync(configPath, cleaned + (cleaned.endsWith('\n') ? '' : '\n'));
NODE
  report_event "Skills and Plugins" "RTK" "Configuration Entries Removed" "$config_path telemetry.enabled" "ok"
}

remove_rtk_telemetry_shell_env() {
  local profile_path="$1"
  local start_marker="# token-saver-setup managed RTK telemetry start"
  local end_marker="# token-saver-setup managed RTK telemetry end"

  if [ "$dry_run" = "1" ]; then
    report_event "Skills and Plugins" "RTK" "Configuration Entries Removed" "dry-run: would remove managed RTK shell telemetry env from $profile_path" "ok"
    return 0
  fi

  [ -f "$profile_path" ] || return 0
  local temp
  temp="$(mktemp)"
  local removing=0
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$line" = "$start_marker" ]; then
      removing=1
      continue
    fi
    if [ "$line" = "$end_marker" ] && [ "$removing" = "1" ]; then
      removing=0
      continue
    fi
    [ "$removing" = "1" ] && continue
    printf '%s\n' "$line" >> "$temp"
  done < "$profile_path"
  mv "$temp" "$profile_path"
  report_event "Skills and Plugins" "RTK" "Configuration Entries Removed" "$profile_path RTK_TELEMETRY_DISABLED block" "ok"
}

install_rtk_binary() {
  if command -v rtk >/dev/null 2>&1; then
    install_event "Skills and Plugins" "RTK" "Files Already Current" "rtk already installed: $(command -v rtk)" "ok"
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    run_cmd brew install rtk
    return 0
  fi

  if [ "$allow_unverified_downloads" != "1" ]; then
    if [ "$dry_run" = "1" ]; then
      install_event "Skills and Plugins" "RTK" "Shell Commands Skipped" "dry-run: skipping unverified RTK fallback download; rerun with --allow-unverified-downloads to permit legacy curl | sh" "warn"
    else
      printf 'warning: skipping unverified RTK fallback download; install RTK with Homebrew or rerun with --allow-unverified-downloads\n' >&2
    fi
    return 0
  fi

  if command -v curl >/dev/null 2>&1; then
    if [ "$dry_run" = "1" ]; then
      install_event "Skills and Plugins" "RTK" "Shell Commands Run" "dry-run: unverified: curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh" "warn"
    else
      curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
      install_event "Skills and Plugins" "RTK" "Shell Commands Run" "unverified: curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh" "warn"
    fi
    return 0
  fi

  printf 'warning: could not install RTK; install curl or Homebrew and rerun\n' >&2
}

rtk_init_arg() {
  case "$1" in
    claude|"") printf '%s\n' "-g --auto-patch" ;;
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
  current_tool="RTK"
  install_rtk_binary
  ensure_rtk_telemetry_disabled
  ensure_rtk_telemetry_shell_env

  if ! command -v rtk >/dev/null 2>&1 && [ "$dry_run" != "1" ]; then
    printf 'warning: rtk not found on PATH after install; skipping rtk init\n' >&2
    return 0
  fi

  old_ifs="$IFS"
  IFS=","
  for agent in $ai_apps; do
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
  for agent in $ai_apps; do
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
    install_event "Verification" "RTK" "Verification Checks" "dry-run: would verify RTK binary and assistant instruction wiring" "ok"
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

  install_event "Verification" "RTK" "Verification Checks" "verified RTK setup" "ok"
}

install_caveman_agent_fallbacks() {
  local old_ifs app

  current_tool="Caveman"
  if [ "$allow_unverified_downloads" != "1" ]; then
    if [ "$dry_run" = "1" ]; then
      install_event "Skills and Plugins" "Caveman" "Shell Commands Skipped" "dry-run: skipping unverified Caveman remote installer commands; rerun with --allow-unverified-downloads to permit legacy remote installs" "warn"
    else
      printf 'warning: skipping unverified Caveman remote installer commands; rerun with --allow-unverified-downloads to permit legacy remote installs\n' >&2
    fi
    return 0
  fi
  old_ifs="$IFS"
  IFS=","
  for app in $ai_apps; do
    IFS="$old_ifs"
    app="$(printf '%s' "$app" | xargs)"
    case "$app" in
      claude)
        run_interactive_cmd claude plugin marketplace add JuliusBrussee/caveman
        run_interactive_cmd claude plugin install caveman@caveman
        ;;
      gemini)
        run_interactive_cmd gemini extensions install https://github.com/JuliusBrussee/caveman
        ;;
      opencode)
        run_interactive_cmd npx -y github:JuliusBrussee/caveman -- --only opencode
        ;;
      openclaw)
        run_interactive_cmd npx -y github:JuliusBrussee/caveman -- --only openclaw
        ;;
      codex)
        if [ "$non_interactive" = "1" ]; then
          run_cmd npx skills add JuliusBrussee/caveman -a codex --yes --global
        else
          run_interactive_cmd npx skills add JuliusBrussee/caveman -a codex
        fi
        ;;
      cursor)
        if [ "$non_interactive" = "1" ]; then
          run_cmd npx skills add JuliusBrussee/caveman -a cursor --yes --global
        else
          run_interactive_cmd npx skills add JuliusBrussee/caveman -a cursor
        fi
        ;;
      copilot)
        run_interactive_cmd npx -y github:JuliusBrussee/caveman -- --only copilot --with-init
        ;;
    esac
    IFS=","
  done
  IFS="$old_ifs"

  return 0
}

install_caveman_tool() {
  [ "$install_caveman" = "1" ] || return 0
  current_tool="Caveman"

  if [ "$dry_run" = "1" ]; then
    install_event "Skills and Plugins" "Caveman" "Configuration Entries Updated" "dry-run: would write caveman default mode $caveman_mode" "ok"
  else
    mkdir -p "$HOME/.config/caveman"
    printf '{\n  "defaultMode": "%s"\n}\n' "$caveman_mode" > "$HOME/.config/caveman/config.json"
    install_event "Skills and Plugins" "Caveman" "Configuration Entries Updated" "wrote caveman default mode $caveman_mode" "ok"
  fi

  record_manifest "file" "caveman" "installer-created" "created-or-modified" "$HOME/.config/caveman/config.json"
  install_caveman_agent_fallbacks
  say "Caveman install step complete. Continuing setup..."
}

install_global_instruction_files() {
  if app_selected claude; then
    copy_global_instruction_file "$ROOT/templates/CLAUDE.global.md" "$HOME/.claude/CLAUDE.md"
  fi
  if app_selected codex; then
    render_global_instruction_template "$ROOT/templates/AGENTS.global.md" "$HOME/.codex/AGENTS.md"
  fi
}

install_project_instruction_files() {
  if app_selected claude; then
    copy_project_template_file "$ROOT/templates/CLAUDE.project-template.md" "$HOME/.claude/CLAUDE.project-template.md"
  fi
  if app_selected codex; then
    copy_project_template_file "$ROOT/templates/AGENTS.project-template.md" "$HOME/.codex/AGENTS.project-template.md"
  fi

  render_template "$ROOT/scripts/seed-project-instructions.sh" "$HOME/.agents/scripts/seed-project-instructions.sh"
  if [ "$dry_run" != "1" ]; then
    chmod +x "$HOME/.agents/scripts/seed-project-instructions.sh"
  fi

  if app_selected claude; then
    merge_claude_session_hook
  fi
}

install_ai_ignore_boundaries() {
  copy_managed_file "$ROOT/scripts/optimize-ai.sh" "$HOME/.agents/scripts/optimize-ai.sh" "ignore-optimizer"
  if [ "$dry_run" != "1" ]; then
    chmod +x "$HOME/.agents/scripts/optimize-ai.sh"
  fi
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

progress_bar() {
  local current="$1"
  local total="$2"
  local width="30"
  local filled empty
  filled=$(( current * width / total ))
  empty=$(( width - filled ))
  printf '%*s' "$filled" "" | tr ' ' '#'
  printf '%*s' "$empty" "" | tr ' ' '-'
}

progress_line() {
  local prefix="$1"
  local current="$2"
  local total="$3"
  local message="$4"
  local bar
  bar="$(progress_bar "$current" "$total")"
  printf '%s [%s] %s/%s %s\n' "$prefix" "$bar" "$current" "$total" "$message"
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

install_event() {
  local section="$1"
  local tool="$2"
  local category="$3"
  local item="$4"
  local status="${5:-ok}"

  [ -n "$install_report_file" ] || return 0
  printf '%s\t%s\t%s\t%s\t%s\n' "$section" "$tool" "$category" "$item" "$status" >> "$install_report_file"
}

install_file_event() {
  local component="$1"
  local category="$2"
  local item="$3"

  case "$component" in
    global-instructions)
      install_event "Instruction Files" "" "$category" "$item" "ok"
      ;;
    project-templates)
      install_event "Templates" "" "$category" "$item" "ok"
      ;;
    *)
      install_event "Skills and Plugins" "$(tool_for_component "$component")" "$category" "$item" "ok"
      ;;
  esac
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

report_install_summary() {
  [ -s "$install_report_file" ] || return 0
  if command -v node >/dev/null 2>&1; then
    node - "$install_report_file" <<'NODE'
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
const printRows = (items) => {
  for (const row of items) console.log(`${symbol(row.status)} ${row.item}`);
};

const instruction = rows.filter((r) => r.section === "Instruction Files");
if (instruction.length) {
  printSection("Instruction Files");
  for (const category of unique(instruction.map((r) => r.category))) {
    const entries = instruction.filter((r) => r.category === category);
    console.log(`${category} (${unique(entries.map((r) => r.item)).length})`);
    printRows(entries);
  }
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
    for (const category of unique(owned.map((r) => r.category))) {
      const entries = owned.filter((r) => r.category === category);
      console.log(`${category} (${unique(entries.map((r) => r.item)).length})`);
      printRows(entries);
    }
    console.log("Status");
    console.log("✓ Successfully Installed");
    console.log("");
  }
}

const templates = rows.filter((r) => r.section === "Templates");
if (templates.length) {
  printSection("Templates");
  for (const category of unique(templates.map((r) => r.category))) {
    const entries = templates.filter((r) => r.category === category);
    console.log(`${category} (${unique(entries.map((r) => r.item)).length})`);
    printRows(entries);
  }
  console.log("");
}

const config = rows.filter((r) => r.section === "Configuration");
if (config.length) {
  printSection("Configuration");
  printRows(config);
  console.log("");
}

const verification = rows.filter((r) => r.section === "Verification");
const verificationIssues = verification.filter((r) => r.status === "warn" || r.category === "Verification Issues");
if (verification.length) {
  printSection("Verification", "=");
  printRows(verification);
  console.log("");
}

const count = (category) => unique(rows.filter((r) => r.category === category).map((r) => r.item)).length;
printSection("Summary");
console.log(`Files Installed: ${count("Files Installed")}`);
console.log(`Files Overwritten: ${count("Files Overwritten")}`);
console.log(`Files Already Current: ${count("Files Already Current")}`);
console.log(`Files Skipped: ${count("Files Skipped")}`);
console.log(`Shell Commands Run: ${count("Shell Commands Run")}`);
console.log(`Configuration Entries Updated: ${count("Configuration Entries Updated")}`);
console.log(`Verification Issues: ${verificationIssues.length}`);
NODE
  else
    cat "$install_report_file"
  fi
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
  const originalValue = item.details && item.details.originalValue ? item.details.originalValue : "";
  const createdSection = item.details && item.details.createdSection ? "1" : "0";
  console.log([item.type || "", item.ownership || "", item.path || "", key, command, originalValue, createdSection].join("\t"));
}
NODE
}

uninstall_manifest_component() {
  local component="$1"
  local type ownership target key command originalValue createdSection

  manifest_artifacts_for_component "$component" | while IFS="$(printf '\t')" read -r type ownership target key command originalValue createdSection; do
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
          rtk)
            case "$key" in
              hooks.PreToolUse) remove_rtk_claude_hook ;;
              telemetry.enabled) remove_rtk_telemetry_config "$target" "$originalValue" ;;
              shell.RTK_TELEMETRY_DISABLED) remove_rtk_telemetry_shell_env "$target" ;;
              *) remove_rtk_claude_hook ;;
            esac ;;
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

remove_rtk_claude_hook() {
  local settings_path="$HOME/.claude/settings.json"

  if [ "$dry_run" = "1" ]; then
    if [ "$uninstall_active" = "1" ]; then
      report_event "Skills and Plugins" "RTK" "Configuration Entries Removed" "$settings_path hooks.PreToolUse rtk hook claude" "ok"
    else
      printf 'dry-run: would remove RTK Claude hook from %s\n' "$settings_path"
    fi
    return 0
  fi

  [ -f "$settings_path" ] || return 0
  command -v node >/dev/null 2>&1 || { printf 'warning: node required to edit %s; skipping\n' "$settings_path" >&2; return 0; }

  node - "$settings_path" <<'NODE'
const fs = require("fs");
const settingsPath = process.argv[2];
const raw = fs.readFileSync(settingsPath, "utf8").trim();
let data = {};
try {
  data = raw ? JSON.parse(raw) : {};
} catch (error) {
  fs.copyFileSync(settingsPath, `${settingsPath}.bak`);
  console.error(`error: invalid JSON in ${settingsPath}; backup created at ${settingsPath}.bak`);
  process.exit(1);
}
if (data.hooks && Array.isArray(data.hooks.PreToolUse)) {
  data.hooks.PreToolUse = data.hooks.PreToolUse
    .map((entry) => ({
      ...entry,
      hooks: Array.isArray(entry.hooks)
        ? entry.hooks.filter((hook) => !(hook && hook.type === "command" && hook.command === "rtk hook claude"))
        : entry.hooks,
    }))
    .filter((entry) => !Array.isArray(entry.hooks) || entry.hooks.length > 0);
}
const output = JSON.stringify(data, null, 2) + "\n";
JSON.parse(output);
const tmp = `${settingsPath}.tmp.${process.pid}`;
fs.writeFileSync(tmp, output, { mode: fs.statSync(settingsPath).mode });
fs.renameSync(tmp, settingsPath);
NODE
  report_event "Skills and Plugins" "RTK" "Configuration Entries Removed" "$settings_path hooks.PreToolUse rtk hook claude" "ok"
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
const hasCavemanOrCavecrew = (value) => {
  const text = JSON.stringify(value || "").toLowerCase();
  return text.includes("caveman") || text.includes("cavecrew");
};

if (data.hooks && typeof data.hooks === "object") {
  for (const key of Object.keys(data.hooks)) {
    if (Array.isArray(data.hooks[key])) {
      data.hooks[key] = data.hooks[key]
        .map((entry) => ({
          ...entry,
          hooks: Array.isArray(entry.hooks) ? entry.hooks.filter((hook) => !hasCavemanOrCavecrew(hook)) : entry.hooks,
        }))
        .filter((entry) => !Array.isArray(entry.hooks) || entry.hooks.length > 0);
    }
  }
}
if (hasCavemanOrCavecrew(data.statusLine)) delete data.statusLine;
for (const prop of ["mcpServers", "plugins", "enabledPlugins"]) {
  if (data[prop] && typeof data[prop] === "object") {
    for (const key of Object.keys(data[prop])) {
      if (key.toLowerCase().includes("caveman") || key.toLowerCase().includes("cavecrew") || hasCavemanOrCavecrew(data[prop][key])) delete data[prop][key];
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
      "[mcp_servers.fs_shrunk]"|"[hooks.state./Users/burljohnson/.agents/skills/i-caveman/SKILL.md]"|"[hooks.state./Users/burljohnson/.agents/skills/cavecrew/SKILL.md]"|"[hooks.state.*cavecrew]*")
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
      *caveman*|*Caveman*|*cavecrew*|*Cavecrew*|*mcps*|*MCPs*) continue ;;
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
  remove_rtk_claude_hook
  remove_path "$HOME/.codex/RTK.md"
  remove_path "$HOME/.claude/RTK.md"
  remove_path "$HOME/.agents/rules/antigravity-rtk-rules.md"
  remove_glob_paths "$HOME/.agents/rules/*rtk*"
}

uninstall_caveman_components() {
  local skill

  current_tool="Caveman"
  if [ "$allow_unverified_downloads" != "1" ]; then
    report_event "Verification" "Caveman" "Verification Issues" "skipping unverified Caveman npx uninstall commands; rerun with --allow-unverified-downloads to permit legacy remote uninstall" "warn"
  elif command -v npx >/dev/null 2>&1 || [ "$dry_run" = "1" ]; then
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
  remove_path "$HOME/.agents/skills/cavecrew"
  remove_path "$HOME/.claude/skills/cavecrew"
  remove_glob_paths "$HOME/.agents/skills/*cavecrew*"
  remove_glob_paths "$HOME/.claude/skills/*cavecrew*"
  remove_glob_paths "$HOME/.claude/projects/*caveman*"
  remove_caveman_claude_settings
  remove_caveman_codex_config
}

uninstall_selected_components() {
  local old_ifs component used_manifest=0 total=0 current=0

  if [ -z "$uninstall_components" ] && [ "$non_interactive" = "1" ]; then
    uninstall_components="all available"
  fi

  for component in $(printf '%s\n' "$(selected_components)" | tr ',' '\n'); do
    total=$((total + 1))
  done

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
    current=$((current + 1))
    progress_line "Uninstall" "$current" "$total" "${component//-/ }"
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
  local total=0 current=0
  for component in $(printf '%s\n' "$(selected_components)" | tr ',' '\n'); do
    total=$((total + 1))
  done

  if component_selected "global-instructions"; then
    current=$((current + 1))
    progress_line "Uninstall" "$current" "$total" "global instructions"
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
  say "uninstall complete"
  rm -f "$uninstall_report_file"
  exit 0
fi

ai_apps="$(prompt_text "AI apps to configure" "$ai_apps")"
ai_apps="$(normalize_ai_apps "$ai_apps")"
assets="$(normalize_assets "$assets")"
rtk_agents="$ai_apps"

install_steps=5
install_step=0
install_active=1
install_report_file="$(mktemp)"

if asset_selected rtk && [ "$install_rtk" != "0" ] && prompt_yes_no "Install RTK for selected AI apps?" "yes"; then
  install_rtk=1
  install_step=$((install_step + 1))
  progress_line "Install" "$install_step" "$install_steps" "RTK initialization"
  initialize_rtk_agents

  install_step=$((install_step + 1))
  progress_line "Install" "$install_step" "$install_steps" "RTK Claude hook"
  ensure_rtk_claude_hook

  install_step=$((install_step + 1))
  progress_line "Install" "$install_step" "$install_steps" "RTK verification"
  verify_rtk_setup
else
  install_rtk=0
fi

if asset_selected caveman && [ "$install_caveman" != "0" ] && prompt_yes_no "Install Caveman for selected AI apps?" "yes"; then
  install_caveman=1
  if [ "$non_interactive" != "1" ]; then
    caveman_mode="$(prompt_text "Caveman mode to use ($caveman_modes)" "$caveman_mode")"
  fi
  validate_caveman_mode "$caveman_mode"
  install_step=$((install_step + 1))
  progress_line "Install" "$install_step" "$install_steps" "Caveman install"
  install_caveman_tool
else
  install_caveman=0
fi

if asset_selected global-instructions && prompt_yes_no "Install global instruction files for selected AI apps?" "yes"; then
  if prompt_yes_no "Overwrite existing global instruction files?" "no"; then
    overwrite_global_instructions=1
  fi
  install_step=$((install_step + 1))
  progress_line "Install" "$install_step" "$install_steps" "global instructions"
  install_global_instruction_files
fi

if asset_selected project-instructions && prompt_yes_no "Install project instruction files for selected AI apps?" "yes"; then
  project_scope="$(prompt_text "Enter project directory for project seeding instructions" "$project_scope")"
  if prompt_yes_no "Overwrite existing project instruction template files?" "no"; then
    overwrite_project_templates=1
  fi
  install_step=$((install_step + 1))
  progress_line "Install" "$install_step" "$install_steps" "project instructions"
  install_project_instruction_files
fi

if asset_selected ai-ignore-boundaries && prompt_yes_no "Install AI ignore boundaries for selected AI apps?" "yes"; then
  install_step=$((install_step + 1))
  progress_line "Install" "$install_step" "$install_steps" "AI ignore boundaries"
  install_ai_ignore_boundaries
fi

report_install_summary
say "setup complete"
rm -f "$install_report_file"
