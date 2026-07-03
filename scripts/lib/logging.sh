#!/usr/bin/env bash

# Keep installer logs under the shared agents home unless a test or caller
# overrides the path.
install_log="${TOKEN_SAVER_LOG:-$agents_home/install.log}"

# Redact Context7 credentials from dry-run output and persisted logs.
redact_text() {
  sed -E \
    -e 's/CONTEXT7_API_KEY=[^[:space:]]+/CONTEXT7_API_KEY=<redacted>/g' \
    -e 's/(--api-key)[[:space:]]+[^[:space:]]+/\1 <redacted>/g' \
    -e 's/(CONTEXT7_API_KEY: )[^"]+/\1<redacted>/g'
}

# Append a timestamped, redacted line to the install log.
log_line() {
  local message="$*"

  mkdir -p "$(dirname "$install_log")"
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$message" | redact_text >> "$install_log"
}

# Print and log the current high-level installer step.
step() {
  say "Step: $*"
  log_line "step=$*"
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
