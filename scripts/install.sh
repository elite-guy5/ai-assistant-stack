#!/usr/bin/env bash
set -euo pipefail

# Initialize global installer state before sourcing helper libraries that depend
# on these variables.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dry_run=0
non_interactive=0
overwrite=0
overwrite_global=0
overwrite_templates=0
tools=""
repo_path=""
apply_current_repo=""
uninstall=0

agents_home="${TOKEN_SAVER_HOME:-$HOME/.agents}"
state_file="${TOKEN_SAVER_STATE:-$agents_home/install_state}"
git_template_dir="$agents_home/git-template"
seeder_target="$agents_home/scripts/seed-project-instructions.sh"

# Load target parsing, logging, preflight, and stack-tool helpers from the
# repository so install behavior stays centralized.
# shellcheck source=/dev/null
. "$ROOT/scripts/lib/targets.sh"
# shellcheck source=/dev/null
. "$ROOT/scripts/lib/logging.sh"
# shellcheck source=/dev/null
. "$ROOT/scripts/lib/preflight.sh"
# shellcheck source=/dev/null
. "$ROOT/scripts/lib/stack-tools.sh"

# Print command-line help for auto-detected stack installs and legacy
# instruction-file installs.
usage() {
  cat <<'EOF'
Usage: bash scripts/install.sh [options]

Options:
  --targets <list>         Optional comma-separated product targets:
                           codex,claude,vscode. Auto-detected when omitted.
  --tools <codex|claude|both>
                           Legacy instruction-file tools to configure.
                           Skips third-party stack setup.
  --repo <path>            Also seed and install managed hooks in this Git repo.
  --non-interactive        Do not prompt.
  --dry-run                Print actions without changing files.
  --overwrite              Back up and replace existing managed target files.
  --overwrite-global-instructions
                           Back up and replace existing global instruction files.
  --overwrite-project-templates
                           Back up and replace existing project template files.
  --uninstall              Remove installer-managed files and hook entries.
  --help                   Show this help.
EOF
}

# Print a normal status line to stdout.
say() {
  printf '%s\n' "$*"
}

# Print an error and terminate the installer.
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

# Execute a command unless --dry-run is active, in which case print the command
# to the redacted install log instead of crowding the progress output.
run() {
  if [ "$dry_run" = "1" ]; then
    if command -v redact_text >/dev/null 2>&1; then
      log_line "dry_run_command=$*"
    fi
    return 0
  fi
  "$@"
}

# Append a managed resource entry to the installer state file for uninstall.
record_state() {
  local key="$1"
  local value="$2"

  [ "$dry_run" = "0" ] || return 0
  mkdir -p "$(dirname "$state_file")"
  if [ -f "$state_file" ]; then
    grep -v -F "$key|$value" "$state_file" > "$state_file.tmp" || true
    mv "$state_file.tmp" "$state_file"
  fi
  printf '%s|%s\n' "$key" "$value" >> "$state_file"
}

# Store one current value for state keys where only the latest value matters.
record_single_state() {
  local key="$1"
  local value="$2"

  [ "$dry_run" = "0" ] || return 0
  mkdir -p "$(dirname "$state_file")"
  if [ -f "$state_file" ]; then
    grep -v -F "$key|" "$state_file" > "$state_file.tmp" || true
    mv "$state_file.tmp" "$state_file"
  fi
  printf '%s|%s\n' "$key" "$value" >> "$state_file"
}

# Normalize legacy --tools aliases to the canonical tool selector.
normalize_tools() {
  local value="$1"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
  case "$value" in
    codex|agent|agents) printf 'codex' ;;
    claude|claude-code|claudecode) printf 'claude' ;;
    both|all|codex,claude|claude,codex) printf 'both' ;;
    *) die "invalid --tools value: $1" ;;
  esac
}

# Return success when the canonical tool selector includes the requested tool.
tool_enabled() {
  case "$tools:$1" in
    both:*|codex:codex|claude:claude) return 0 ;;
    *) return 1 ;;
  esac
}

# Prompt for the legacy tool selector when the user does not pass --targets or
# --tools in interactive mode.
prompt_tools() {
  local choice
  cat <<'EOF'
Which tool should this installer configure?
  1) Codex
  2) Claude Code
  3) Both
EOF
  printf 'Selection [3]: '
  read_prompt_value choice
  case "${choice:-3}" in
    1|codex|Codex) tools="codex" ;;
    2|claude|Claude|claude-code) tools="claude" ;;
    3|both|Both) tools="both" ;;
    *) die "invalid selection: $choice" ;;
  esac
}

# Read a yes/no answer with a default value for optional interactive actions.
prompt_yes_no() {
  local prompt="$1"
  local default="$2"
  local answer suffix

  if [ "$default" = "yes" ]; then
    suffix='[Y/n]'
  else
    suffix='[y/N]'
  fi

  printf '%s %s ' "$prompt" "$suffix"
  read_prompt_value answer
  answer="${answer:-$default}"
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# Build a timestamped backup filename next to a file that may be replaced.
backup_path() {
  local path="$1"
  printf '%s.token-saver-backup-%s' "$path" "$(date +%Y%m%d%H%M%S)"
}

# Install a managed template file, preserving user-owned files unless overwrite
# was requested.
install_file() {
  local source="$1"
  local target="$2"
  local replace="$3"
  local label="$4"
  local backup

  [ -f "$source" ] || die "missing source template: $source"

  if [ -e "$target" ]; then
    if [ "$replace" != "1" ] && [ "$non_interactive" = "0" ]; then
      if prompt_yes_no "Replace existing $target?" "no"; then
        replace=1
      fi
    fi

    if [ "$replace" = "1" ]; then
      backup="$(backup_path "$target")"
      status_ok "Backing up $target to $backup"
      run mkdir -p "$(dirname "$target")"
      run cp "$target" "$backup"
    else
      status_skipped "Existing $target"
      return 0
    fi
  fi

  status_ok "Installed $target"
  run mkdir -p "$(dirname "$target")"
  run cp "$source" "$target"
  record_state "managed_file" "$target"
  record_state "managed_component" "$label:$target"
}

# Install the project instruction seeding script into the shared agents home.
install_seeder() {
  status_ok "Installed $seeder_target"
  run mkdir -p "$(dirname "$seeder_target")"
  run cp "$ROOT/scripts/seed-project-instructions.sh" "$seeder_target"
  run chmod +x "$seeder_target"
  record_state "managed_file" "$seeder_target"
}

# Generate the managed Git hook body, wrapping any backed-up hook first and then
# seeding project instructions for the configured tools.
hook_body() {
  local existing="${1:-}"
  cat <<EOF
#!/usr/bin/env bash
# TOKEN_SAVER_MANAGED_HOOK_BEGIN
set -e
# Run the user's original hook first when this installer backed one up.
if [ -n "$existing" ] && [ -x "$existing" ]; then
  "$existing" "\$@" || exit \$?
fi
# Seed project instruction files after checkout or merge without blocking Git.
TOKEN_SAVER_TOOLS="$tools" "\$HOME/.agents/scripts/seed-project-instructions.sh" --tools "$tools" "\$(pwd)" >/dev/null 2>&1 || true
# TOKEN_SAVER_MANAGED_HOOK_END
EOF
}

# Install or update one managed Git hook while backing up pre-existing custom
# hook content.
install_hook_file() {
  local hook="$1"
  local label="$2"
  local backup=""

  if [ -f "$hook" ] && grep -q 'TOKEN_SAVER_MANAGED_HOOK_BEGIN' "$hook"; then
    status_ok "Updated Git $label hook $hook"
  elif [ -e "$hook" ]; then
    backup="$(backup_path "$hook")"
    status_ok "Backing up existing Git $label hook to $backup"
    run mv "$hook" "$backup"
    record_state "hook_backup" "$hook=>$backup"
  else
    status_ok "Installed Git $label hook $hook"
  fi

  run mkdir -p "$(dirname "$hook")"
  if [ "$dry_run" = "0" ]; then
    hook_body "$backup" > "$hook"
    chmod +x "$hook"
  else
    status_dry_run "write managed hook $hook"
  fi
  record_state "managed_hook" "$hook"
}

# Install managed hooks into Git's template directory and remember any previous
# global init.templateDir value for uninstall.
install_git_template_hooks() {
  local previous

  phase "Git hooks"
  install_hook_file "$git_template_dir/hooks/post-checkout" "template post-checkout"
  install_hook_file "$git_template_dir/hooks/post-merge" "template post-merge"

  previous="$(git config --global --get init.templateDir 2>/dev/null || true)"
  if [ "$previous" != "$git_template_dir" ]; then
    record_single_state "previous_init_template_dir" "${previous:-__unset__}"
    status_ok "Configured git init.templateDir to $git_template_dir"
    run git config --global init.templateDir "$git_template_dir"
  else
    status_ok "git init.templateDir already points to $git_template_dir"
  fi
}

# Return the repository root for a path, or an empty value when outside Git.
git_root_for() {
  git -C "$1" rev-parse --show-toplevel 2>/dev/null || true
}

# Seed an existing repository and install managed post-checkout/post-merge hooks
# into that repository's .git directory.
install_current_repo_hooks() {
  local repo="$1"
  local git_dir
  local root
  local seed_args

  root="$(git_root_for "$repo")"
  [ -n "$root" ] || die "not inside a Git repository: $repo"
  git_dir="$(git -C "$root" rev-parse --git-dir)"
  case "$git_dir" in
    /*) ;;
    *) git_dir="$root/$git_dir" ;;
  esac

  phase "Current repository"
  status_ok "Seeding current repo $root"
  seed_args=("$seeder_target" --tools "$tools")
  [ "$overwrite" = "1" ] && seed_args+=(--overwrite)
  seed_args+=("$root")
  run "${seed_args[@]}"
  install_hook_file "$git_dir/hooks/post-checkout" "repo post-checkout"
  install_hook_file "$git_dir/hooks/post-merge" "repo post-merge"
}

# Install global instruction files and project templates for selected tools.
install_instruction_files() {
  local global_replace="$overwrite"
  local template_replace="$overwrite"

  phase "Instruction files"
  [ "$overwrite_global" = "1" ] && global_replace=1
  [ "$overwrite_templates" = "1" ] && template_replace=1

  if tool_enabled codex; then
    install_file "$ROOT/templates/AGENTS.global.md" "$HOME/.codex/AGENTS.md" "$global_replace" "codex-global"
    install_file "$ROOT/templates/AGENTS.project-template.md" "$HOME/.codex/AGENTS.project-template.md" "$template_replace" "codex-template"
  fi

  if tool_enabled claude; then
    install_file "$ROOT/templates/CLAUDE.global.md" "$HOME/.claude/CLAUDE.md" "$global_replace" "claude-global"
    install_file "$ROOT/templates/CLAUDE.project-template.md" "$HOME/.claude/CLAUDE.project-template.md" "$template_replace" "claude-template"
  fi
}

# Remove one managed hook when the uninstall flow sees it in state.
remove_managed_hook() {
  local hook="$1"
  if [ -f "$hook" ] && grep -q 'TOKEN_SAVER_MANAGED_HOOK_BEGIN' "$hook"; then
    say "Removed managed hook $hook"
    run rm -f "$hook"
  fi
}

# Remove installer-managed files and hooks, restore saved hooks, and reset
# init.templateDir when this installer set it.
uninstall_all() {
  local line key value previous
  local hook backup

  if [ ! -f "$state_file" ]; then
    say "No install state found at $state_file"
    return 0
  fi

  while IFS='|' read -r key value; do
    case "$key" in
      managed_file)
        if [ -e "$value" ]; then
          say "Removed managed file $value"
          run rm -f "$value"
        fi
        ;;
      managed_hook)
        remove_managed_hook "$value"
        ;;
    esac
  done < "$state_file"

  while IFS='|' read -r key value; do
    case "$key" in
      hook_backup)
        hook="${value%%=>*}"
        backup="${value#*=>}"
        if [ ! -e "$hook" ] && [ -e "$backup" ]; then
          say "Restored original hook $hook"
          run mv "$backup" "$hook"
        fi
        ;;
    esac
  done < "$state_file"

  previous="$(awk -F'|' '$1 == "previous_init_template_dir" { value=$2 } END { print value }' "$state_file")"
  if [ "$(git config --global --get init.templateDir 2>/dev/null || true)" = "$git_template_dir" ]; then
    if [ "$previous" = "__unset__" ] || [ -z "$previous" ]; then
      say "Unset git init.templateDir"
      run git config --global --unset init.templateDir
    else
      say "Restored git init.templateDir to $previous"
      run git config --global init.templateDir "$previous"
    fi
  fi

  say "Removed install state $state_file"
  run rm -f "$state_file"
}

# Parse command-line options before any filesystem changes are attempted.
while [ "$#" -gt 0 ]; do
  case "$1" in
    --tools)
      [ "$#" -gt 1 ] || die "missing value for --tools"
      tools="$(normalize_tools "$2")"
      shift
      ;;
    --tools=*) tools="$(normalize_tools "${1#*=}")" ;;
    --targets)
      [ "$#" -gt 1 ] || die "missing value for --targets"
      targets="$(normalize_targets "$2")"
      target_mode=1
      shift
      ;;
    --targets=*)
      targets="$(normalize_targets "${1#*=}")"
      target_mode=1
      ;;
    --repo)
      [ "$#" -gt 1 ] || die "missing value for --repo"
      repo_path="$2"
      apply_current_repo=1
      shift
      ;;
    --repo=*) repo_path="${1#*=}"; apply_current_repo=1 ;;
    --non-interactive) non_interactive=1 ;;
    --dry-run) dry_run=1 ;;
    --overwrite) overwrite=1 ;;
    --overwrite-global-instructions) overwrite_global=1 ;;
    --overwrite-project-templates) overwrite_templates=1 ;;
    --uninstall) uninstall=1 ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# Run uninstall as a separate early exit path so no install setup happens.
if [ "$uninstall" = "1" ]; then
  uninstall_all
  exit 0
fi

# Start the audit log before target/tool selection and install steps.
step "Initialize install log"
log_kv "dry_run" "$dry_run"

# Derive legacy tool selection from explicit or auto-detected targets. The
# legacy --tools path remains instruction-file-only for compatibility.
if [ "$target_mode" = "1" ]; then
  tools="$(derive_tools_from_targets)"
elif [ -z "$tools" ]; then
  targets="$(auto_detect_targets)"
  target_mode=1
  tools="$(derive_tools_from_targets)"
fi

# Report the normalized selection to stdout and to the install log.
if [ "$target_mode" = "1" ]; then
  phase "Selected targets"
  log_kv "selected_targets" "$targets"
  target_enabled codex && status_ok "Codex"
  target_enabled claude && status_ok "Claude"
  target_enabled vscode && status_ok "VS Code"
fi
if [ -n "$tools" ]; then
  phase "Selected tools"
  status_ok "$tools"
  log_kv "selected_tools" "$tools"
else
  phase "Selected tools"
  status_ok "none"
  log_kv "selected_tools" "none"
fi
[ -n "${CONTEXT7_API_KEY:-}" ] && log_line "CONTEXT7_API_KEY=$CONTEXT7_API_KEY"

# For target-mode installs, validate prerequisites before making changes and
# configure stack tools before writing instruction files.
if [ "$target_mode" = "1" ]; then
  preflight_targets
  install_stack_tools
fi

# In interactive use from inside a repository, offer to seed and hook the current
# checkout unless --repo already made the choice explicit.
if [ "$non_interactive" = "0" ] && [ -z "$apply_current_repo" ]; then
  current_root="$(git_root_for "$PWD")"
  if [ -n "$current_root" ] && prompt_yes_no "Also install hooks and seed the current repo at $current_root?" "yes"; then
    repo_path="$current_root"
    apply_current_repo=1
  fi
fi

# Install the shared instruction files, seeder script, and future-repository Git
# template hooks.
if [ -n "$tools" ]; then
  install_instruction_files
  install_seeder
  install_git_template_hooks
fi

# Optionally apply the same seeding and hooks to an existing repository.
if [ -n "$apply_current_repo" ] && [ -n "$tools" ]; then
  install_current_repo_hooks "${repo_path:-$PWD}"
fi

phase "Summary"
status_ok "Install complete"
print_log_summary
