#!/usr/bin/env bash
set -euo pipefail

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

# shellcheck source=/dev/null
. "$ROOT/scripts/lib/targets.sh"

usage() {
  cat <<'EOF'
Usage: bash scripts/install.sh [options]

Options:
  --targets <list>         Comma-separated target surfaces:
                           codex-desktop,codex-vscode,claude-desktop,claude-vscode.
                           Derives --tools automatically.
  --tools <codex|claude|both>
                           Legacy instruction-file tools to configure.
                           Required with --non-interactive when --targets is absent.
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

say() {
  printf '%s\n' "$*"
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

run() {
  if [ "$dry_run" = "1" ]; then
    printf 'dry-run: %s\n' "$*"
    return 0
  fi
  "$@"
}

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

tool_enabled() {
  case "$tools:$1" in
    both:*|codex:codex|claude:claude) return 0 ;;
    *) return 1 ;;
  esac
}

prompt_tools() {
  local choice
  cat <<'EOF'
Which tool should this installer configure?
  1) Codex
  2) Claude Code
  3) Both
EOF
  printf 'Selection [3]: '
  read -r choice
  case "${choice:-3}" in
    1|codex|Codex) tools="codex" ;;
    2|claude|Claude|claude-code) tools="claude" ;;
    3|both|Both) tools="both" ;;
    *) die "invalid selection: $choice" ;;
  esac
}

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
  read -r answer
  answer="${answer:-$default}"
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

backup_path() {
  local path="$1"
  printf '%s.token-saver-backup-%s' "$path" "$(date +%Y%m%d%H%M%S)"
}

install_file() {
  local source="$1"
  local target="$2"
  local replace="$3"
  local label="$4"
  local backup

  [ -f "$source" ] || die "missing source template: $source"

  if [ -e "$target" ]; then
    if [ "$replace" = "1" ]; then
      backup="$(backup_path "$target")"
      say "Backing up $target to $backup"
      run mkdir -p "$(dirname "$target")"
      run cp "$target" "$backup"
    else
      say "Skipped existing $target"
      return 0
    fi
  fi

  say "Installed $target"
  run mkdir -p "$(dirname "$target")"
  run cp "$source" "$target"
  record_state "managed_file" "$target"
  record_state "managed_component" "$label:$target"
}

install_seeder() {
  say "Installed $seeder_target"
  run mkdir -p "$(dirname "$seeder_target")"
  run cp "$ROOT/scripts/seed-project-instructions.sh" "$seeder_target"
  run chmod +x "$seeder_target"
  record_state "managed_file" "$seeder_target"
}

hook_body() {
  local existing="${1:-}"
  cat <<EOF
#!/usr/bin/env bash
# TOKEN_SAVER_MANAGED_HOOK_BEGIN
set -e
if [ -n "$existing" ] && [ -x "$existing" ]; then
  "$existing" "\$@" || exit \$?
fi
TOKEN_SAVER_TOOLS="$tools" "\$HOME/.agents/scripts/seed-project-instructions.sh" --tools "$tools" "\$(pwd)" >/dev/null 2>&1 || true
# TOKEN_SAVER_MANAGED_HOOK_END
EOF
}

install_hook_file() {
  local hook="$1"
  local label="$2"
  local backup=""

  if [ -f "$hook" ] && grep -q 'TOKEN_SAVER_MANAGED_HOOK_BEGIN' "$hook"; then
    say "Updated Git $label hook $hook"
  elif [ -e "$hook" ]; then
    backup="$(backup_path "$hook")"
    say "Backing up existing Git $label hook to $backup"
    run mv "$hook" "$backup"
    record_state "hook_backup" "$hook=>$backup"
  else
    say "Installed Git $label hook $hook"
  fi

  run mkdir -p "$(dirname "$hook")"
  if [ "$dry_run" = "0" ]; then
    hook_body "$backup" > "$hook"
    chmod +x "$hook"
  else
    printf 'dry-run: write managed hook %s\n' "$hook"
  fi
  record_state "managed_hook" "$hook"
}

install_git_template_hooks() {
  local previous

  install_hook_file "$git_template_dir/hooks/post-checkout" "template post-checkout"
  install_hook_file "$git_template_dir/hooks/post-merge" "template post-merge"

  previous="$(git config --global --get init.templateDir 2>/dev/null || true)"
  if [ "$previous" != "$git_template_dir" ]; then
    record_single_state "previous_init_template_dir" "${previous:-__unset__}"
    say "Configured git init.templateDir to $git_template_dir"
    run git config --global init.templateDir "$git_template_dir"
  else
    say "git init.templateDir already points to $git_template_dir"
  fi
}

git_root_for() {
  git -C "$1" rev-parse --show-toplevel 2>/dev/null || true
}

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

  say "Seeding current repo $root"
  seed_args=("$seeder_target" --tools "$tools")
  [ "$overwrite" = "1" ] && seed_args+=(--overwrite)
  seed_args+=("$root")
  run "${seed_args[@]}"
  install_hook_file "$git_dir/hooks/post-checkout" "repo post-checkout"
  install_hook_file "$git_dir/hooks/post-merge" "repo post-merge"
}

install_instruction_files() {
  local global_replace="$overwrite"
  local template_replace="$overwrite"

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

remove_managed_hook() {
  local hook="$1"
  if [ -f "$hook" ] && grep -q 'TOKEN_SAVER_MANAGED_HOOK_BEGIN' "$hook"; then
    say "Removed managed hook $hook"
    run rm -f "$hook"
  fi
}

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

if [ "$uninstall" = "1" ]; then
  uninstall_all
  exit 0
fi

if [ "$target_mode" = "1" ]; then
  tools="$(derive_tools_from_targets)"
elif [ -z "$tools" ]; then
  if [ "$non_interactive" = "1" ]; then
    die "--targets or --tools is required in non-interactive mode"
  fi
  prompt_targets
fi

if [ "$non_interactive" = "0" ] && [ -z "$apply_current_repo" ]; then
  current_root="$(git_root_for "$PWD")"
  if [ -n "$current_root" ] && prompt_yes_no "Also install hooks and seed the current repo at $current_root?" "yes"; then
    repo_path="$current_root"
    apply_current_repo=1
  fi
fi

if [ "$target_mode" = "1" ]; then
  say "Selected targets: $targets"
fi
say "Selected tools: $tools"
install_instruction_files
install_seeder
install_git_template_hooks

if [ -n "$apply_current_repo" ]; then
  install_current_repo_hooks "${repo_path:-$PWD}"
fi

say "Install complete"
