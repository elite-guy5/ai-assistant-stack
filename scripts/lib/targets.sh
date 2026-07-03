#!/usr/bin/env bash

# Store target-mode selection globally so install.sh can derive tool behavior
# after parsing arguments or prompts.
targets=""
target_mode=0
target_values=(codex-desktop codex-vscode claude-desktop claude-vscode)
target_labels=("Codex Desktop" "Codex VS Code" "Claude Desktop" "Claude VS Code")
target_count=4
selector_test_keys="${TOKEN_SAVER_TEST_KEYS-}"

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

# Prompt for target surfaces with a keyboard checklist. Targets intentionally
# start unselected so the installer never applies to every surface by default.
prompt_targets() {
  local focus=0
  local key selected message=""

  if [ -z "$selector_test_keys" ] && { [ ! -r /dev/tty ] || [ ! -w /dev/tty ]; }; then
    die "interactive target selection requires a terminal; rerun with --targets codex-desktop,codex-vscode,claude-desktop,claude-vscode"
  fi

  target_selected=(0 0 0 0)

  while true; do
    # Real terminal redraws replace the selector in place; captured test output
    # keeps every render so tests can inspect the initial empty state.
    if [ -t 1 ]; then
      printf '\033[H\033[J'
    fi
    render_target_selector "$focus" "$message"
    message=""

    read_selector_key key || die "interactive target selection requires a terminal; rerun with --targets codex-desktop,codex-vscode,claude-desktop,claude-vscode"
    case "$key" in
      up)
        focus=$((focus - 1))
        [ "$focus" -lt 0 ] && focus=$((target_count - 1))
        ;;
      down)
        focus=$((focus + 1))
        [ "$focus" -ge "$target_count" ] && focus=0
        ;;
      space)
        if [ "${target_selected[$focus]}" = "1" ]; then
          target_selected[$focus]=0
        else
          target_selected[$focus]=1
        fi
        ;;
      enter)
        selected="$(selected_targets_value)"
        if [ -z "$selected" ]; then
          message="Select at least one target before continuing."
        else
          targets="$(normalize_targets "$selected")"
          target_mode=1
          tools="$(derive_tools_from_targets)"
          return 0
        fi
        ;;
    esac
  done
}

# Only colorize the filled marker when stdout is a terminal. Logs and captured
# test output stay readable without ANSI escapes.
selector_color_enabled() {
  [ -t 1 ] && [ -z "${NO_COLOR:-}" ]
}

selected_mark() {
  if selector_color_enabled; then
    printf '\033[32m●\033[0m'
  else
    printf '●'
  fi
}

unselected_mark() {
  printf '○'
}

# Render one frame of the target selector. The caller owns cursor movement and
# key handling so rendering remains deterministic and easy to test.
render_target_selector() {
  local focus="$1"
  local message="${2:-}"
  local i prefix mark

  printf 'AI Assistant Stack Setup\n\n'
  printf 'Select targets to configure:\n\n'
  for ((i = 0; i < target_count; i += 1)); do
    prefix=' '
    [ "$i" -eq "$focus" ] && prefix='>'
    if [ "${target_selected[$i]}" = "1" ]; then
      mark="$(selected_mark)"
    else
      mark="$(unselected_mark)"
    fi
    printf '%s %s %s\n' "$prefix" "$mark" "${target_labels[$i]}"
  done
  printf '\nSpace toggles, Enter confirms, ↑/↓ or j/k moves.\n'
  [ -z "$message" ] || printf '%s\n' "$message"
}

# Read one logical selector action. Tests set TOKEN_SAVER_TEST_KEYS to avoid
# depending on a real terminal while exercising the same state transitions.
read_selector_key() {
  local __var="$1"
  local raw_key rest

  if [ -n "$selector_test_keys" ]; then
    raw_key="${selector_test_keys:0:1}"
    selector_test_keys="${selector_test_keys:1}"
    case "$raw_key" in
      '') printf -v "$__var" 'eof' ;;
      $'\n'|$'\r') printf -v "$__var" 'enter' ;;
      ' ') printf -v "$__var" 'space' ;;
      j) printf -v "$__var" 'down' ;;
      k) printf -v "$__var" 'up' ;;
      *) printf -v "$__var" 'other' ;;
    esac
    return 0
  fi

  if [ ! -r /dev/tty ] || [ ! -w /dev/tty ]; then
    printf -v "$__var" 'eof'
    return 1
  fi

  # Arrow keys arrive as escape sequences, so ESC needs one short follow-up
  # read to distinguish up/down from unrelated escape input.
  IFS= read -rsn1 raw_key < /dev/tty || {
    printf -v "$__var" 'eof'
    return 1
  }
  if [ "$raw_key" = $'\033' ]; then
    IFS= read -rsn2 -t 0.05 rest < /dev/tty || rest=""
    case "$rest" in
      '[A') printf -v "$__var" 'up' ;;
      '[B') printf -v "$__var" 'down' ;;
      *) printf -v "$__var" 'other' ;;
    esac
    return 0
  fi

  case "$raw_key" in
    $'\n'|$'\r') printf -v "$__var" 'enter' ;;
    ' ') printf -v "$__var" 'space' ;;
    j) printf -v "$__var" 'down' ;;
    k) printf -v "$__var" 'up' ;;
    *) printf -v "$__var" 'other' ;;
  esac
}

# Convert selected checklist rows back to the canonical comma-separated target
# list used by the non-interactive install path.
selected_targets_value() {
  local i selected=""
  for ((i = 0; i < target_count; i += 1)); do
    if [ "${target_selected[$i]}" = "1" ]; then
      selected="${selected:+$selected,}${target_values[$i]}"
    fi
  done
  printf '%s\n' "$selected"
}
