#!/usr/bin/env bash

install_log="${TOKEN_SAVER_LOG:-$agents_home/install.log}"

redact_text() {
  sed -E \
    -e 's/CONTEXT7_API_KEY=[^[:space:]]+/CONTEXT7_API_KEY=<redacted>/g' \
    -e 's/(--api-key)[[:space:]]+[^[:space:]]+/\1 <redacted>/g' \
    -e 's/(CONTEXT7_API_KEY: )[^"]+/\1<redacted>/g'
}

log_line() {
  local message="$*"

  mkdir -p "$(dirname "$install_log")"
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$message" | redact_text >> "$install_log"
}

step() {
  say "Step: $*"
  log_line "step=$*"
}

log_kv() {
  log_line "$1=$2"
}

run_logged() {
  log_line "command=$*"
  run "$@"
}
