#!/usr/bin/env bash

# Store target-mode selection globally so install.sh can derive tool behavior
# after parsing arguments or prompts.
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

# Normalize a comma-separated target list, reject unknown targets, and remove
# duplicates while preserving selection order.
normalize_targets() {
  local raw="$1"
  local normalized=""
  local item
  local old_ifs="$IFS"

  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
  [ -n "$raw" ] || die "missing value for --targets"

  IFS=','
  for item in $raw; do
    case "$item" in
      codex-desktop|codex-vscode|claude-desktop|claude-vscode) ;;
      *) IFS="$old_ifs"; die "invalid --targets value: $item" ;;
    esac
    case ",$normalized," in
      *",$item,"*) ;;
      *) normalized="${normalized:+$normalized,}$item" ;;
    esac
  done
  IFS="$old_ifs"

  printf '%s\n' "$normalized"
}

# Return success when the normalized target list includes a specific surface.
target_enabled() {
  case ",$targets," in
    *",$1,"*) return 0 ;;
    *) return 1 ;;
  esac
}

# Collapse selected target surfaces into the legacy tool selector used by
# instruction-file installation.
derive_tools_from_targets() {
  local has_codex=0
  local has_claude=0

  target_enabled codex-desktop && has_codex=1
  target_enabled codex-vscode && has_codex=1
  target_enabled claude-desktop && has_claude=1
  target_enabled claude-vscode && has_claude=1

  case "$has_codex:$has_claude" in
    1:1) printf 'both\n' ;;
    1:0) printf 'codex\n' ;;
    0:1) printf 'claude\n' ;;
    *) die "no supported targets selected" ;;
  esac
}

# Prompt for target surfaces and map numeric menu selections to canonical names.
prompt_targets() {
  local choice

  cat <<'EOF'
Which AI surfaces should this installer configure?
  1) Codex Desktop
  2) Codex VS Code
  3) Claude Desktop
  4) Claude VS Code
  5) All
Enter comma-separated selections [5]:
EOF
  printf 'Selection [5]: '
  read_prompt_value choice
  choice="${choice:-5}"

  case "$choice" in
    1) targets="codex-desktop" ;;
    2) targets="codex-vscode" ;;
    3) targets="claude-desktop" ;;
    4) targets="claude-vscode" ;;
    5) targets="codex-desktop,codex-vscode,claude-desktop,claude-vscode" ;;
    *)
      choice="$(printf '%s' "$choice" | sed 's/1/codex-desktop/g; s/2/codex-vscode/g; s/3/claude-desktop/g; s/4/claude-vscode/g; s/5/codex-desktop,codex-vscode,claude-desktop,claude-vscode/g')"
      targets="$(normalize_targets "$choice")"
      ;;
  esac

  targets="$(normalize_targets "$targets")"
  target_mode=1
  tools="$(derive_tools_from_targets)"
}
