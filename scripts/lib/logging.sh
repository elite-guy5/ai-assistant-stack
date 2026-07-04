#!/usr/bin/env bash

# Keep installer logs under the shared agents home unless a test or caller
# overrides the path.
install_log="${TOKEN_SAVER_LOG:-$agents_home/install.log}"
install_title_printed=0

# Redact Context7 credentials from dry-run output and persisted logs.
redact_text() {
  sed -E \
    -e 's/CONTEXT7_API_KEY=[^[:space:]]+/CONTEXT7_API_KEY=<redacted>/g' \
    -e 's/(--api-key)[[:space:]]+[^[:space:]]+/\1 <redacted>/g' \
    -e 's/(CONTEXT7_API_KEY: )[^[:space:]]+/\1<redacted>/g'
}

# Append a timestamped, redacted line to the install log.
log_line() {
  local message="$*"

  mkdir -p "$(dirname "$install_log")"
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$message" | redact_text >> "$install_log"
}

# Print the installer title once, even when many phases are reported.
print_title() {
  local red=""
  local silver=""
  local reset=""

  [ "$install_title_printed" = "0" ] || return 0
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    red="$(printf '\033[1;31m')"
    silver="$(printf '\033[38;5;250m')"
    reset="$(printf '\033[0m')"
  fi
  cat <<EOF
${red} █████╗ ██╗
${red}██╔══██╗██║
${red}███████║██║
${red}██╔══██║██║
${red}██║  ██║██║
${red}╚═╝  ╚═╝╚═╝

${silver} █████╗ ███████╗███████╗██╗███████╗████████╗ █████╗ ███╗   ██╗████████╗
${silver}██╔══██╗██╔════╝██╔════╝██║██╔════╝╚══██╔══╝██╔══██╗████╗  ██║╚══██╔══╝
${silver}███████║███████╗███████╗██║███████╗   ██║   ███████║██╔██╗ ██║   ██║
${silver}██╔══██║╚════██║╚════██║██║╚════██║   ██║   ██╔══██║██║╚██╗██║   ██║
${silver}██║  ██║███████║███████║██║███████║   ██║   ██║  ██║██║ ╚████║   ██║
${silver}╚═╝  ╚═╝╚══════╝╚══════╝╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝

${red}███████╗████████╗ █████╗  ██████╗██╗  ██╗
${red}██╔════╝╚══██╔══╝██╔══██╗██╔════╝██║ ██╔╝
${red}███████╗   ██║   ███████║██║     █████╔╝
${red}╚════██║   ██║   ██╔══██║██║     ██╔═██╗
${red}███████║   ██║   ██║  ██║╚██████╗██║  ██╗
${red}╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝

${silver}             Your AI Assistant Stack${reset}
EOF
  say ""
  install_title_printed=1
}

# Print and log the current high-level installer phase.
phase() {
  print_title
  say ""
  say "$*"
  log_line "phase=$*"
}

# Keep the older step API as an alias because install helpers already use it.
step() {
  phase "$*"
}

# Print one indented status row under the current phase.
status_line() {
  local status="$1"
  shift
  say "  $status $*"
}

status_ok() {
  status_line "OK" "$@"
}

status_skipped() {
  status_line "Skipped" "$@"
}

status_warning() {
  status_line "Warning" "$@"
}

status_dry_run() {
  status_line "Dry run" "$@"
}

# End the run with the exact log path for detailed troubleshooting.
print_log_summary() {
  status_line "Log" "$install_log"
}

# Log a key/value pair using the common log-line format.
log_kv() {
  log_line "$1=$2"
}

# Log a command before routing it through the installer's dry-run-aware runner.
run_logged() {
  log_line "command=$*"
  run "$@"
}
