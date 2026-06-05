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
  bash "$ROOT/scripts/install.sh" --dry-run --non-interactive
)"

printf '%s\n' "$output" | grep -Fq 'dry-run: rtk init -g --auto-patch'
printf '%s\n' "$output" | grep -Fq 'dry-run: rtk init -g --codex'
if printf '%s\n' "$output" | grep -Eq 'rtk init -g --gemini|rtk init -g --agent cursor'; then
  printf 'default non-interactive install included non-default AI apps\n' >&2
  exit 1
fi
printf '%s\n' "$output" | grep -Fq 'dry-run: would write caveman default mode ultra'
printf '%s\n' "$output" | grep -Fq 'dry-run: claude plugin marketplace add JuliusBrussee/caveman'
printf '%s\n' "$output" | grep -Fq 'dry-run: claude plugin install caveman@caveman'
printf '%s\n' "$output" | grep -Fq 'dry-run: npx skills add JuliusBrussee/caveman -a codex --yes --global'
printf '%s\n' "$output" | grep -Fq 'dry-run: would ensure RTK telemetry disabled'
printf '%s\n' "$output" | grep -Fq 'dry-run: would ensure RTK_TELEMETRY_DISABLED=1 is present'
printf '%s\n' "$output" | grep -Fq 'Instruction Files'
printf '%s\n' "$output" | grep -Fq 'Skills and Plugins'
printf '%s\n' "$output" | grep -Fq 'Files Skipped'
printf '%s\n' "$output" | grep -Fq 'Shell Commands Run'
printf '%s\n' "$output" | grep -Fq 'Summary'
printf '%s\n' "$output" | grep -Fq 'Files Skipped:'
printf '%s\n' "$output" | grep -Fq 'Shell Commands Run:'

skip_output="$(
  bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --skip-rtk --skip-caveman
)"

if printf '%s\n' "$skip_output" | grep -Eq 'rtk init|caveman default|github:JuliusBrussee/caveman|skills add JuliusBrussee/caveman'; then
  printf 'skip flags did not suppress RTK/Caveman actions\n' >&2
  exit 1
fi

scoped_caveman_output="$(
  bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --ai-apps codex,cursor --assets caveman
)"

printf '%s\n' "$scoped_caveman_output" | grep -Fq 'dry-run: npx skills add JuliusBrussee/caveman -a codex --yes --global'
printf '%s\n' "$scoped_caveman_output" | grep -Fq 'dry-run: npx skills add JuliusBrussee/caveman -a cursor --yes --global'
if printf '%s\n' "$scoped_caveman_output" | grep -Eq 'rtk init|claude plugin|gemini extensions install|--only opencode|--only openclaw|--only copilot'; then
  printf 'app-scoped Caveman install ran unexpected commands\n' >&2
  exit 1
fi

extended_caveman_output="$(
  bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --ai-apps claude,gemini,opencode,openclaw,copilot --assets caveman
)"

printf '%s\n' "$extended_caveman_output" | grep -Fq 'dry-run: claude plugin marketplace add JuliusBrussee/caveman'
printf '%s\n' "$extended_caveman_output" | grep -Fq 'dry-run: claude plugin install caveman@caveman'
printf '%s\n' "$extended_caveman_output" | grep -Fq 'dry-run: gemini extensions install https://github.com/JuliusBrussee/caveman'
printf '%s\n' "$extended_caveman_output" | grep -Fq 'dry-run: npx -y github:JuliusBrussee/caveman -- --only opencode'
printf '%s\n' "$extended_caveman_output" | grep -Fq 'dry-run: npx -y github:JuliusBrussee/caveman -- --only openclaw'
printf '%s\n' "$extended_caveman_output" | grep -Fq 'dry-run: npx -y github:JuliusBrussee/caveman -- --only copilot --with-init'

scoped_rtk_output="$(
  bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --ai-apps opencode,openclaw,copilot --assets rtk
)"

printf '%s\n' "$scoped_rtk_output" | grep -Fq 'dry-run: rtk init --agent opencode'
printf '%s\n' "$scoped_rtk_output" | grep -Fq 'dry-run: rtk init --agent openclaw'
printf '%s\n' "$scoped_rtk_output" | grep -Fq 'dry-run: rtk init -g --copilot'
if printf '%s\n' "$scoped_rtk_output" | grep -Eq 'rtk init -g$|--codex|--gemini|--agent cursor|caveman'; then
  printf 'app-scoped RTK install ran unexpected commands\n' >&2
  exit 1
fi

claude_rtk_output="$(
  bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --ai-apps claude --assets rtk
)"
printf '%s\n' "$claude_rtk_output" | grep -Fq 'dry-run: rtk init -g --auto-patch'

if command -v expect >/dev/null 2>&1; then
  expect_script="$tmp/install-order.exp"
  cat > "$expect_script" <<'EOF'
set timeout 10
spawn bash scripts/install.sh --dry-run
expect -exact {AI apps to configure [claude,codex]: }
send "codex,cursor\r"
expect -exact {Install RTK for selected AI apps? (y/n) [y]: }
send "n\r"
expect -exact {Install Caveman for selected AI apps? (y/n) [y]: }
send "n\r"
expect -exact {Install global instruction files for selected AI apps? (y/n) [y]: }
send "n\r"
expect -exact {Install project instruction files for selected AI apps? (y/n) [y]: }
send "n\r"
expect -exact {Install AI ignore boundaries for selected AI apps? (y/n) [y]: }
send "n\r"
expect eof
EOF
  if ! (cd "$ROOT" && HOME="$HOME" PATH="$PATH" expect "$expect_script" >/dev/null); then
    printf 'install prompt order failed\n' >&2
    exit 1
  fi

  caveman_expect_script="$tmp/interactive-caveman.exp"
  cat > "$caveman_expect_script" <<'EOF'
set timeout 10
spawn bash scripts/install.sh --dry-run --ai-apps codex,cursor --assets caveman
expect -exact {AI apps to configure [codex,cursor]: }
send "\r"
expect -exact {Install Caveman for selected AI apps? (y/n) [y]: }
send "y\r"
expect -exact {Caveman mode to use (lite,full,ultra,wenyan-lite,wenyan-full,wenyan-ultra) [ultra]: }
send "\r"
expect eof
EOF
  interactive_output_file="$tmp/interactive-caveman-output.txt"
  if ! (cd "$ROOT" && HOME="$HOME" PATH="$PATH" expect "$caveman_expect_script" > "$interactive_output_file"); then
    printf 'interactive Caveman prompt failed\n' >&2
    exit 1
  fi
  interactive_caveman_output="$(cat "$interactive_output_file")"
  printf '%s\n' "$interactive_caveman_output" | grep -Fq 'dry-run: npx skills add JuliusBrussee/caveman -a codex'
  printf '%s\n' "$interactive_caveman_output" | grep -Fq 'dry-run: npx skills add JuliusBrussee/caveman -a cursor'
  if printf '%s\n' "$interactive_caveman_output" | grep -Eq -- '--yes|--global'; then
    printf 'interactive Caveman skill install should not force --yes/--global\n' >&2
    exit 1
  fi
fi

if command -v pwsh >/dev/null 2>&1; then
  ps_output="$(
    pwsh -NoProfile -File "$ROOT/scripts/install.ps1" -DryRun -NonInteractive
  )"

  printf '%s\n' "$ps_output" | grep -Fq 'dry-run: rtk init -g --auto-patch'
  printf '%s\n' "$ps_output" | grep -Fq 'dry-run: rtk init -g --codex'
  printf '%s\n' "$ps_output" | grep -Fq 'dry-run: would ensure RTK telemetry disabled'
  printf '%s\n' "$ps_output" | grep -Fq 'dry-run: would ensure RTK_TELEMETRY_DISABLED=1 is present'
  if printf '%s\n' "$ps_output" | grep -Eq 'rtk init -g --gemini|rtk init -g --agent cursor'; then
    printf 'PowerShell default non-interactive install included non-default AI apps\n' >&2
    exit 1
  fi
  printf '%s\n' "$ps_output" | grep -Fq 'dry-run: would write caveman default mode ultra'
  printf '%s\n' "$ps_output" | grep -Fq 'dry-run: claude plugin marketplace add JuliusBrussee/caveman'
  printf '%s\n' "$ps_output" | grep -Fq 'dry-run: claude plugin install caveman@caveman'
  printf '%s\n' "$ps_output" | grep -Fq 'dry-run: npx skills add JuliusBrussee/caveman -a codex --yes --global'
  printf '%s\n' "$ps_output" | grep -Fq 'Instruction Files'
  printf '%s\n' "$ps_output" | grep -Fq 'Skills and Plugins'
  printf '%s\n' "$ps_output" | grep -Fq 'Files Skipped'
  printf '%s\n' "$ps_output" | grep -Fq 'Shell Commands Run'
  printf '%s\n' "$ps_output" | grep -Fq 'Summary'
  printf '%s\n' "$ps_output" | grep -Fq 'Files Skipped:'
  printf '%s\n' "$ps_output" | grep -Fq 'Shell Commands Run:'

  ps_skip_output="$(
    pwsh -NoProfile -File "$ROOT/scripts/install.ps1" -DryRun -NonInteractive -SkipRtk -SkipCaveman
  )"

  if printf '%s\n' "$ps_skip_output" | grep -Eq 'rtk init|caveman default|github:JuliusBrussee/caveman|skills add JuliusBrussee/caveman'; then
    printf 'PowerShell skip flags did not suppress RTK/Caveman actions\n' >&2
    exit 1
  fi

  ps_scoped_caveman_output="$(
    pwsh -NoProfile -File "$ROOT/scripts/install.ps1" -DryRun -NonInteractive -AiApps codex,cursor -Assets caveman
  )"
  printf '%s\n' "$ps_scoped_caveman_output" | grep -Fq 'dry-run: npx skills add JuliusBrussee/caveman -a codex --yes --global'
  printf '%s\n' "$ps_scoped_caveman_output" | grep -Fq 'dry-run: npx skills add JuliusBrussee/caveman -a cursor --yes --global'

  ps_extended_caveman_output="$(
    pwsh -NoProfile -File "$ROOT/scripts/install.ps1" -DryRun -NonInteractive -AiApps claude,gemini,opencode,openclaw,copilot -Assets caveman
  )"
  printf '%s\n' "$ps_extended_caveman_output" | grep -Fq 'dry-run: claude plugin marketplace add JuliusBrussee/caveman'
  printf '%s\n' "$ps_extended_caveman_output" | grep -Fq 'dry-run: claude plugin install caveman@caveman'
  printf '%s\n' "$ps_extended_caveman_output" | grep -Fq 'dry-run: gemini extensions install https://github.com/JuliusBrussee/caveman'
  printf '%s\n' "$ps_extended_caveman_output" | grep -Fq 'dry-run: npx -y github:JuliusBrussee/caveman -- --only opencode'
  printf '%s\n' "$ps_extended_caveman_output" | grep -Fq 'dry-run: npx -y github:JuliusBrussee/caveman -- --only openclaw'
  printf '%s\n' "$ps_extended_caveman_output" | grep -Fq 'dry-run: npx -y github:JuliusBrussee/caveman -- --only copilot --with-init'

  ps_scoped_rtk_output="$(
    pwsh -NoProfile -File "$ROOT/scripts/install.ps1" -DryRun -NonInteractive -AiApps opencode,openclaw,copilot -Assets rtk
  )"
  printf '%s\n' "$ps_scoped_rtk_output" | grep -Fq 'dry-run: rtk init --agent opencode'
  printf '%s\n' "$ps_scoped_rtk_output" | grep -Fq 'dry-run: rtk init --agent openclaw'
  printf '%s\n' "$ps_scoped_rtk_output" | grep -Fq 'dry-run: rtk init -g --copilot'

  ps_claude_rtk_output="$(
    pwsh -NoProfile -File "$ROOT/scripts/install.ps1" -DryRun -NonInteractive -AiApps claude -Assets rtk
  )"
  printf '%s\n' "$ps_claude_rtk_output" | grep -Fq 'dry-run: rtk init -g --auto-patch'
fi
