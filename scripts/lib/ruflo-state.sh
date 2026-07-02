#!/usr/bin/env bash

ruflo_home="${RUFLO_HOME:-$HOME/.ruflo}"

report_ruflo_state() {
  local root="$PWD"
  local path

  step "Check Ruflo runtime state"
  say "Ruflo runtime state root: $ruflo_home"
  log_kv "ruflo_home" "$ruflo_home"

  for path in .ruflo .claude-flow .swarm agentdb.rvf agentdb.rvf.lock ruvector.db; do
    if [ -e "$root/$path" ]; then
      say "Warning: project-local Ruflo state path found: $root/$path"
      log_line "ruflo_project_state=$root/$path"
    fi
  done
}

ensure_ruflo_home() {
  step "Prepare Ruflo runtime state"
  say "Ruflo runtime state root: $ruflo_home"
  run_logged mkdir -p "$ruflo_home"
}
