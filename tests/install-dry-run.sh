#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
export PATH="$tmp/bin:$PATH"
mkdir -p "$HOME" "$tmp/bin"

stub_command() {
  local name="$1"
  printf '#!/usr/bin/env sh\nexit 0\n' > "$tmp/bin/$name"
  chmod +x "$tmp/bin/$name"
}

stub_command rtk
stub_command npx
stub_command claude
stub_command codex
stub_command gemini
stub_command cursor

output="$(
  bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --rtk-agents claude --caveman-args "--skip-skills"
)"

printf '%s\n' "$output" | grep -Fq 'dry-run: rtk init -g'
printf '%s\n' "$output" | grep -Fq 'dry-run: rtk init -g --codex'
printf '%s\n' "$output" | grep -Fq 'dry-run: rtk init -g --gemini'
printf '%s\n' "$output" | grep -Fq 'dry-run: rtk init -g --agent cursor'
printf '%s\n' "$output" | grep -Fq 'dry-run: would write caveman default mode ultra'
printf '%s\n' "$output" | grep -Fq 'dry-run: npx -y github:JuliusBrussee/caveman -- --all --skip-skills --non-interactive --dry-run'
printf '%s\n' "$output" | grep -Fq 'dry-run: gemini extensions install https://github.com/JuliusBrussee/caveman'
printf '%s\n' "$output" | grep -Fq 'dry-run: npx skills add JuliusBrussee/caveman -a codex'
printf '%s\n' "$output" | grep -Fq 'dry-run: npx skills add JuliusBrussee/caveman -a cursor'

skip_output="$(
  bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --skip-rtk --skip-caveman
)"

if printf '%s\n' "$skip_output" | grep -Eq 'rtk init|caveman default|github:JuliusBrussee/caveman|skills add JuliusBrussee/caveman'; then
  printf 'skip flags did not suppress RTK/Caveman actions\n' >&2
  exit 1
fi

if command -v pwsh >/dev/null 2>&1; then
  ps_output="$(
    pwsh -NoProfile -File "$ROOT/scripts/install.ps1" -DryRun -NonInteractive -RtkAgents claude -CavemanArgs "--skip-skills"
  )"

  printf '%s\n' "$ps_output" | grep -Fq 'dry-run: rtk init -g'
  printf '%s\n' "$ps_output" | grep -Fq 'dry-run: rtk init -g --codex'
  printf '%s\n' "$ps_output" | grep -Fq 'dry-run: rtk init -g --gemini'
  printf '%s\n' "$ps_output" | grep -Fq 'dry-run: rtk init -g --agent cursor'
  printf '%s\n' "$ps_output" | grep -Fq 'dry-run: would write caveman default mode ultra'
  printf '%s\n' "$ps_output" | grep -Fq 'dry-run: npx -y github:JuliusBrussee/caveman -- --all --skip-skills --non-interactive --dry-run'
  printf '%s\n' "$ps_output" | grep -Fq 'dry-run: gemini extensions install https://github.com/JuliusBrussee/caveman'
  printf '%s\n' "$ps_output" | grep -Fq 'dry-run: npx skills add JuliusBrussee/caveman -a codex'
  printf '%s\n' "$ps_output" | grep -Fq 'dry-run: npx skills add JuliusBrussee/caveman -a cursor'

  ps_skip_output="$(
    pwsh -NoProfile -File "$ROOT/scripts/install.ps1" -DryRun -NonInteractive -SkipRtk -SkipCaveman
  )"

  if printf '%s\n' "$ps_skip_output" | grep -Eq 'rtk init|caveman default|github:JuliusBrussee/caveman|skills add JuliusBrussee/caveman'; then
    printf 'PowerShell skip flags did not suppress RTK/Caveman actions\n' >&2
    exit 1
  fi
fi
