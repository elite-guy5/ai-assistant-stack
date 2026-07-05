#!/usr/bin/env bash
set -euo pipefail

# Locate the repository and create an isolated temporary workspace for this test
# file.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Assert that command output includes an expected substring.
assert_contains() {
  case "$1" in
    *"$2"*) ;;
    *)
      printf 'expected output to contain: %s\noutput was:\n%s\n' "$2" "$1" >&2
      exit 1
      ;;
  esac
}

# Assert that command output does not include an unwanted substring.
assert_not_contains() {
  case "$1" in
    *"$2"*)
      printf 'expected output not to contain: %s\noutput was:\n%s\n' "$2" "$1" >&2
      exit 1
      ;;
    *) ;;
  esac
}

# Verify target-mode setup fails during preflight when Context7 credentials are
# missing, before any stack setup begins.
context7_credentials_required() {
  local home="$tmp/home-context7"
  local output
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  chmod +x "$home/bin/codex"

  if HOME="$home" PATH="$home/bin:$PATH" \
    bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets codex >"$tmp/context7.out" 2>"$tmp/context7.err"; then
    printf 'missing Context7 credentials unexpectedly succeeded\n' >&2
    exit 1
  fi

  output="$(cat "$tmp/context7.out")$(cat "$tmp/context7.err")"
  assert_contains "$output" "Preflight selected targets"
  assert_contains "$output" "missing prerequisite for selected targets: Context7 API key"
  assert_contains "$(cat "$tmp/context7.err")" "export CONTEXT7_API_KEY=\"your-context7-api-key\""
  assert_not_contains "$output" "Install LeanCTX"
  assert_not_contains "$output" "Configure Context7"
}

# Verify Codex target dry-run output includes every stack setup step with
# secrets redacted.
dry_run_prints_stack_steps_for_codex() {
  local home="$tmp/home-stack-codex"
  local output log
  mkdir -p "$home/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  chmod +x "$home/bin/codex"

  output="$(
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" CONTEXT7_API_KEY=test-key \
      bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets codex
  )"
  log="$home/.agents/install.log"

  assert_contains "$output" "Install LeanCTX"
  assert_contains "$output" "Dry run Configure LeanCTX setup"
  assert_contains "$output" "Dry run Disable LeanCTX path jail"
  assert_contains "$output" "Dry run Enable LeanCTX proxy"
  assert_contains "$output" "Dry run Enable LeanCTX Codex ChatGPT proxy"
  assert_contains "$output" "Configure Context7"
  assert_contains "$output" "Install Caveman"
  assert_contains "$output" "Dry run Check Codex skill caveman"
  assert_contains "$output" "Dry run Install all Caveman skills for Codex"
  assert_contains "$output" "Install Superpowers"
  assert_contains "$output" "Dry run Check Codex plugin superpowers@openai-curated"
  assert_contains "$output" "Dry run Install Superpowers for Codex"
  assert_contains "$output" "Dry run Limit Superpowers skills to manual invocation"
  assert_contains "$output" "Dry run Configure Context7 for Codex"
  assert_not_contains "$output" "Configure LeanCTX tools"
  assert_contains "$(cat "$log")" "lean-ctx setup"
  assert_contains "$(cat "$log")" "leanctx_setup_project=$ROOT"
  assert_contains "$(cat "$log")" 'cd "$1"'
  assert_contains "$(cat "$log")" 'cd "$HOME"'
  assert_not_contains "$(cat "$log")" "LEAN_CTX_PROJECT_ROOT"
  assert_contains "$(cat "$log")" "lean-ctx config set path_jail false --yes"
  assert_contains "$(cat "$log")" "lean-ctx proxy enable"
  assert_contains "$(cat "$log")" "lean-ctx proxy codex-chatgpt on"
  assert_contains "$(cat "$log")" "npx skills add JuliusBrussee/caveman --yes --global --agent codex"
  assert_contains "$(cat "$log")" "codex plugin add superpowers@openai-curated"
  assert_contains "$(cat "$log")" "superpowers_manual_activation=dry-run"
  assert_contains "$(cat "$log")" "codex mcp add context7"
  assert_contains "$(cat "$log")" "--api-key <redacted>"
  assert_not_contains "$(cat "$log")" "lean-ctx tools minimal"
  assert_not_contains "$(cat "$log")" "lean-ctx proxy disable"
}

# Verify a bootstrap-style install from the user's home directory can find an
# active project checkout under the normal Documents/git project folder.
dry_run_finds_git_project_from_home() {
  local home="$tmp/home-stack-from-home"
  local bundle="$tmp/bootstrap-payload"
  local project
  local output log

  mkdir -p "$home/bin" "$home/Documents/git/example-project" "$bundle"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/codex"
  chmod +x "$home/bin/codex"
  git -C "$home/Documents/git/example-project" init >/dev/null 2>&1
  project="$(git -C "$home/Documents/git/example-project" rev-parse --show-toplevel)"
  cp -R "$ROOT/scripts" "$bundle/scripts"
  cp -R "$ROOT/templates" "$bundle/templates"

  output="$(
    cd "$home"
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" CONTEXT7_API_KEY="test-key" \
      bash "$bundle/scripts/install.sh" --dry-run --non-interactive --targets codex
  )"
  log="$home/.agents/install.log"

  assert_contains "$output" "Dry run Configure LeanCTX setup"
  assert_contains "$(cat "$log")" "leanctx_setup_project=$project"
  assert_contains "$(cat "$log")" 'cd "$1"'
  assert_contains "$(cat "$log")" 'cd "$HOME"'
  assert_not_contains "$(cat "$log")" "LEAN_CTX_PROJECT_ROOT"
}

# Verify stack commands continue when an upstream installer reports an existing
# config with a nonzero exit code.
stack_command_already_exists_continues() {
  local home="$tmp/home-stack-idempotent"
  local output log
  mkdir -p "$home/bin" "$home/.agents"
  printf '#!/usr/bin/env bash\nprintf "MCP server context7 already exists in user config\\n" >&2\nexit 1\n' > "$home/bin/already"
  printf '#!/usr/bin/env bash\nprintf "next command ran\\n"\n' > "$home/bin/next"
  chmod +x "$home/bin/already" "$home/bin/next"
  log="$home/.agents/install.log"

  output="$(
    HOME="$home" agents_home="$home/.agents" dry_run=0 bash -c '
      ROOT="$1"
      install_log="$2"
      say() { printf "%s\n" "$*"; }
      run() { "$@"; }
      . "$ROOT/scripts/lib/logging.sh"
      . "$ROOT/scripts/lib/stack-tools.sh"
      run_stack_command "Configure Context7 for Claude Code" "$HOME/bin/already"
      run_stack_command "Next step" "$HOME/bin/next"
    ' sh "$ROOT" "$log"
  )"

  assert_contains "$output" "MCP server context7 already exists in user config"
  assert_contains "$output" "OK Configure Context7 for Claude Code already configured"
  assert_contains "$output" "next command ran"
  assert_contains "$output" "OK Next step"
  assert_contains "$(cat "$log")" "idempotent_command=$home/bin/already exit_status=1"
}

# Verify non-idempotent command failures still stop the stack install.
stack_command_real_failure_still_fails() {
  local home="$tmp/home-stack-real-failure"
  local output log
  mkdir -p "$home/bin" "$home/.agents"
  printf '#!/usr/bin/env bash\nprintf "permission denied\\n" >&2\nexit 7\n' > "$home/bin/fail"
  chmod +x "$home/bin/fail"
  log="$home/.agents/install.log"

  if output="$(
    HOME="$home" agents_home="$home/.agents" dry_run=0 bash -c '
      ROOT="$1"
      install_log="$2"
      say() { printf "%s\n" "$*"; }
      run() { "$@"; }
      . "$ROOT/scripts/lib/logging.sh"
      . "$ROOT/scripts/lib/stack-tools.sh"
      run_stack_command "Failing step" "$HOME/bin/fail"
    ' sh "$ROOT" "$log" 2>&1
  )"; then
    printf 'non-idempotent failure unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$output" "permission denied"
  assert_not_contains "$output" "OK Failing step"
}

# Verify installed-state helpers can detect existing tools and fail on invalid
# JSON instead of guessing.
installed_state_helpers_detect_existing_tools() {
  local home="$tmp/home-installed-state"
  local log="$home/.agents/install.log"
  local output
  local node_path
  node_path="$(command -v node || true)"
  [ -n "$node_path" ] || {
    printf 'node is required for this test\n' >&2
    exit 1
  }

  mkdir -p "$home/bin" "$home/.agents"
  ln -s "$node_path" "$home/bin/node"

  printf '#!/usr/bin/env bash\ncase "$*" in\n  "skills list --json --global --agent codex") printf "warning: cache stale\\n" >&2; printf "[{\\"name\\":\\"caveman\\"}]\\n" ;;\n  "skills list --json --global --agent claude-code") printf "[{\\"name\\":\\"caveman\\"}]\\n" ;;\n  *) printf "unexpected npx args: %s\\n" "$*" >&2; exit 9 ;;\nesac\n' > "$home/bin/npx"
  printf '#!/usr/bin/env bash\nif [ "$1 $2" = "plugin list" ]; then printf "PLUGIN STATUS VERSION PATH\\nsuperpowers@openai-curated installed, enabled 1 /tmp/superpowers\\n"; else exit 9; fi\n' > "$home/bin/codex"
  printf '#!/usr/bin/env bash\nif [ "$1 $2" = "plugin list" ]; then printf "[{\\"id\\":\\"superpowers@claude-plugins-official\\"}]\\n"; else exit 9; fi\n' > "$home/bin/claude"
  chmod +x "$home/bin/npx" "$home/bin/codex" "$home/bin/claude"

  output="$(
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" agents_home="$home/.agents" dry_run=0 bash -c '
      ROOT="$1"
      install_log="$2"
      say() { printf "%s\n" "$*"; }
      die() { printf "error: %s\n" "$*" >&2; exit 1; }
      . "$ROOT/scripts/lib/targets.sh"
      . "$ROOT/scripts/lib/logging.sh"
      . "$ROOT/scripts/lib/stack-tools.sh"
      codex_skill_installed caveman && printf "codex-caveman=yes\n"
      codex_plugin_installed superpowers@openai-curated && printf "codex-superpowers=yes\n"
      claude_code_skill_installed caveman && printf "claude-caveman=yes\n"
      claude_plugin_installed superpowers@claude-plugins-official && printf "claude-superpowers=yes\n"
    ' sh "$ROOT" "$log"
  )"

  assert_contains "$output" "codex-caveman=yes"
  assert_contains "$output" "codex-superpowers=yes"
  assert_contains "$output" "claude-caveman=yes"
  assert_contains "$output" "claude-superpowers=yes"
}

# Verify Codex plugin detection accepts current multi-marketplace output with
# banner, path, and blank lines before plugin tables.
codex_plugin_installed_accepts_marketplace_sections() {
  local home="$tmp/home-codex-marketplace-sections"
  local log="$home/.agents/install.log"
  local output
  mkdir -p "$home/bin" "$home/.agents"

  printf '#!/usr/bin/env bash\nif [ "$1 $2" = "plugin list" ]; then\n  printf "Marketplace \`openai-primary-runtime\`\\n"\n  printf "%s/.codex/plugins/marketplaces/openai-primary-runtime/marketplace.json\\n\\n" "$HOME"\n  printf "PLUGIN STATUS VERSION PATH\\n"\n  printf "runtime@openai-primary-runtime installed, enabled 1 %s/.codex/plugins/runtime\\n\\n" "$HOME"\n  printf "Marketplace \`openai-curated\`\\n"\n  printf "%s/.codex/plugins/marketplaces/openai-curated/marketplace.json\\n\\n" "$HOME"\n  printf "PLUGIN STATUS VERSION PATH\\n"\n  printf "superpowers@openai-curated installed, enabled 1 %s/.codex/plugins/superpowers\\n"\nelse\n  exit 9\nfi\n' > "$home/bin/codex"
  chmod +x "$home/bin/codex"

  if ! output="$(
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" agents_home="$home/.agents" dry_run=0 bash -c '
      ROOT="$1"
      install_log="$2"
      say() { printf "%s\n" "$*"; }
      die() { printf "error: %s\n" "$*" >&2; exit 1; }
      . "$ROOT/scripts/lib/targets.sh"
      . "$ROOT/scripts/lib/logging.sh"
      . "$ROOT/scripts/lib/stack-tools.sh"
      codex_plugin_installed superpowers@openai-curated && printf "codex-superpowers=yes\n"
    ' sh "$ROOT" "$log" 2>&1
  )"; then
    printf 'multi-marketplace Codex plugin output unexpectedly failed\n%s\n' "$output" >&2
    exit 1
  fi

  assert_contains "$output" "codex-superpowers=yes"
}

# Verify JSON helper failures are explicit.
installed_state_helpers_reject_invalid_json() {
  local home="$tmp/home-installed-state-invalid-json"
  local log="$home/.agents/install.log"
  local output
  local node_path
  node_path="$(command -v node || true)"
  [ -n "$node_path" ] || {
    printf 'node is required for this test\n' >&2
    exit 1
  }

  mkdir -p "$home/bin" "$home/.agents"
  ln -s "$node_path" "$home/bin/node"
  printf '#!/usr/bin/env bash\nprintf "not-json\\n"\n' > "$home/bin/claude"
  chmod +x "$home/bin/claude"

  if output="$(
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" agents_home="$home/.agents" dry_run=0 bash -c '
      ROOT="$1"
      install_log="$2"
      say() { printf "%s\n" "$*"; }
      die() { printf "error: %s\n" "$*" >&2; exit 1; }
      . "$ROOT/scripts/lib/targets.sh"
      . "$ROOT/scripts/lib/logging.sh"
      . "$ROOT/scripts/lib/stack-tools.sh"
      claude_plugin_installed superpowers@claude-plugins-official
    ' sh "$ROOT" "$log" 2>&1
  )"; then
    printf 'invalid JSON unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$output" "invalid JSON from claude plugin list"
}

# Verify Caveman and Superpowers installers skip selected clients where the tool
# is already installed.
installed_stack_tools_are_skipped() {
  local home="$tmp/home-stack-tools-skipped"
  local log="$home/.agents/install.log"
  local output commands
  local node_path
  node_path="$(command -v node || true)"
  [ -n "$node_path" ] || {
    printf 'node is required for this test\n' >&2
    exit 1
  }

  mkdir -p "$home/bin" "$home/.agents"
  ln -s "$node_path" "$home/bin/node"
  printf '#!/usr/bin/env bash\ncase "$*" in\n  "skills list --json --global --agent codex") printf "[{\\"name\\":\\"caveman\\"}]\\n" ;;\n  "skills list --json --global --agent claude-code") printf "[{\\"name\\":\\"caveman\\"}]\\n" ;;\n  "skills add"*) printf "unexpected install: %%s\\n" "$*" >> "$HOME/commands.log"; exit 8 ;;\n  *) printf "unexpected npx args: %%s\\n" "$*" >&2; exit 9 ;;\nesac\n' > "$home/bin/npx"
  printf '#!/usr/bin/env bash\nprintf "codex %%s\\n" "$*" >> "$HOME/commands.log"\nif [ "$1 $2" = "plugin list" ]; then printf "PLUGIN STATUS VERSION PATH\\nsuperpowers@openai-curated installed, enabled 1 /tmp/superpowers\\n"; exit 0; fi\nexit 8\n' > "$home/bin/codex"
  printf '#!/usr/bin/env bash\nprintf "claude %%s\\n" "$*" >> "$HOME/commands.log"\nif [ "$1 $2 $3" = "plugin list --json" ]; then printf "[{\\"id\\":\\"superpowers@claude-plugins-official\\"}]\\n"; exit 0; fi\nexit 8\n' > "$home/bin/claude"
  chmod +x "$home/bin/npx" "$home/bin/codex" "$home/bin/claude"

  output="$(
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" agents_home="$home/.agents" dry_run=0 bash -c '
      ROOT="$1"
      install_log="$2"
      tools=both
      tool_enabled() {
        case "$tools:$1" in
          both:*|codex:codex|claude:claude) return 0 ;;
          *) return 1 ;;
        esac
      }
      say() { printf "%s\n" "$*"; }
      die() { printf "error: %s\n" "$*" >&2; exit 1; }
      run() { "$@"; }
      . "$ROOT/scripts/lib/targets.sh"
      . "$ROOT/scripts/lib/logging.sh"
      . "$ROOT/scripts/lib/stack-tools.sh"
      install_caveman
      install_superpowers
    ' sh "$ROOT" "$log"
  )"

  assert_contains "$output" "Skipped Caveman already installed for Codex"
  assert_contains "$output" "Skipped Caveman already installed for Claude Code"
  assert_contains "$output" "Skipped Superpowers already installed for Codex"
  assert_contains "$output" "Skipped Superpowers already installed for Claude Code"
  commands="$(cat "$home/commands.log")"
  assert_contains "$commands" "codex plugin list"
  assert_contains "$commands" "claude plugin list --json"
  assert_not_contains "$commands" "plugin add superpowers"
  assert_not_contains "$commands" "plugin install superpowers"
}

# Verify invalid Claude Code skill JSON stops Caveman install instead of falling
# through to install commands.
invalid_claude_skill_json_stops_caveman_install() {
  local home="$tmp/home-invalid-claude-json-caveman"
  local log="$home/.agents/install.log"
  local output commands
  local node_path
  node_path="$(command -v node || true)"
  [ -n "$node_path" ] || {
    printf 'node is required for this test\n' >&2
    exit 1
  }

  mkdir -p "$home/bin" "$home/.agents"
  ln -s "$node_path" "$home/bin/node"
  printf '#!/usr/bin/env bash\nprintf "npx %%s\\n" "$*" >> "$HOME/commands.log"\ncase "$*" in\n  "skills list --json --global --agent codex") printf "[{\\"name\\":\\"caveman\\"}]\\n" ;;\n  "skills list --json --global --agent claude-code") printf "not-json\\n" ;;\n  "skills add"*) printf "unexpected install: %%s\\n" "$*" >> "$HOME/commands.log"; exit 8 ;;\n  *) printf "unexpected npx args: %%s\\n" "$*" >&2; exit 9 ;;\nesac\n' > "$home/bin/npx"
  printf '#!/usr/bin/env bash\nprintf "claude %%s\\n" "$*" >> "$HOME/commands.log"\nexit 8\n' > "$home/bin/claude"
  chmod +x "$home/bin/npx" "$home/bin/claude"

  if output="$(
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" agents_home="$home/.agents" dry_run=0 bash -c '
      ROOT="$1"
      install_log="$2"
      tools=both
      tool_enabled() {
        case "$tools:$1" in
          both:*|codex:codex|claude:claude) return 0 ;;
          *) return 1 ;;
        esac
      }
      say() { printf "%s\n" "$*"; }
      die() { printf "error: %s\n" "$*" >&2; exit 1; }
      run() { "$@"; }
      . "$ROOT/scripts/lib/targets.sh"
      . "$ROOT/scripts/lib/logging.sh"
      . "$ROOT/scripts/lib/stack-tools.sh"
      install_caveman
    ' sh "$ROOT" "$log" 2>&1
  )"; then
    printf 'invalid Claude Code skill JSON unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$output" "invalid JSON from npx skills list"
  commands="$(cat "$home/commands.log")"
  assert_contains "$commands" "npx skills list --json --global --agent claude-code"
  assert_not_contains "$commands" "skills add JuliusBrussee/caveman"
  assert_not_contains "$commands" "plugin marketplace add"
  assert_not_contains "$commands" "plugin install caveman"
}

# Verify invalid Codex skill JSON stops Caveman install instead of falling
# through to install commands.
invalid_codex_skill_json_stops_caveman_install() {
  local home="$tmp/home-invalid-codex-json-caveman"
  local log="$home/.agents/install.log"
  local output commands
  local node_path
  node_path="$(command -v node || true)"
  [ -n "$node_path" ] || {
    printf 'node is required for this test\n' >&2
    exit 1
  }

  mkdir -p "$home/bin" "$home/.agents"
  ln -s "$node_path" "$home/bin/node"
  printf '#!/usr/bin/env bash\ncase "$*" in\n  "skills list --json --global --agent codex") printf "not-json\\n" ;;\n  "skills add"*) printf "unexpected install: %%s\\n" "$*" >> "$HOME/commands.log"; exit 8 ;;\n  *) printf "unexpected npx args: %%s\\n" "$*" >&2; exit 9 ;;\nesac\n' > "$home/bin/npx"
  chmod +x "$home/bin/npx"

  if output="$(
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" agents_home="$home/.agents" dry_run=0 bash -c '
      ROOT="$1"
      install_log="$2"
      tools=codex
      tool_enabled() {
        case "$tools:$1" in
          both:*|codex:codex|claude:claude) return 0 ;;
          *) return 1 ;;
        esac
      }
      say() { printf "%s\n" "$*"; }
      die() { printf "error: %s\n" "$*" >&2; exit 1; }
      run() { "$@"; }
      . "$ROOT/scripts/lib/targets.sh"
      . "$ROOT/scripts/lib/logging.sh"
      . "$ROOT/scripts/lib/stack-tools.sh"
      install_caveman
    ' sh "$ROOT" "$log" 2>&1
  )"; then
    printf 'invalid Codex skill JSON unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$output" "invalid JSON from npx skills list"
  if [ -f "$home/commands.log" ]; then
    commands="$(cat "$home/commands.log")"
  else
    commands=""
  fi
  assert_not_contains "$commands" "skills add"
}

# Verify malformed successful Codex plugin-list output stops Superpowers install
# instead of falling through to plugin add.
malformed_codex_plugin_list_stops_superpowers_install() {
  local home="$tmp/home-malformed-codex-plugin-list"
  local log="$home/.agents/install.log"
  local output commands
  mkdir -p "$home/bin" "$home/.agents"

  printf '#!/usr/bin/env bash\nprintf "codex %%s\\n" "$*" >> "$HOME/commands.log"\nif [ "$1 $2" = "plugin list" ]; then printf "unrecognized output\\n"; exit 0; fi\nprintf "unexpected install: %%s\\n" "$*" >> "$HOME/commands.log"; exit 8\n' > "$home/bin/codex"
  chmod +x "$home/bin/codex"

  if output="$(
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" agents_home="$home/.agents" dry_run=0 bash -c '
      ROOT="$1"
      install_log="$2"
      tools=codex
      tool_enabled() {
        case "$tools:$1" in
          both:*|codex:codex|claude:claude) return 0 ;;
          *) return 1 ;;
        esac
      }
      say() { printf "%s\n" "$*"; }
      die() { printf "error: %s\n" "$*" >&2; exit 1; }
      run() { "$@"; }
      . "$ROOT/scripts/lib/targets.sh"
      . "$ROOT/scripts/lib/logging.sh"
      . "$ROOT/scripts/lib/stack-tools.sh"
      install_superpowers
    ' sh "$ROOT" "$log" 2>&1
  )"; then
    printf 'malformed Codex plugin list unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$output" "invalid output from codex plugin list"
  commands="$(cat "$home/commands.log")"
  assert_contains "$commands" "codex plugin list"
  assert_not_contains "$commands" "plugin add superpowers@openai-curated"
}

# Verify missing Superpowers installs through native Codex and Claude plugin
# commands rather than git clone and symlink setup.
missing_superpowers_uses_plugin_installers() {
  local home="$tmp/home-superpowers-install"
  local log="$home/.agents/install.log"
  local output commands
  local codex_skill claude_skill
  local node_path
  node_path="$(command -v node || true)"
  [ -n "$node_path" ] || {
    printf 'node is required for this test\n' >&2
    exit 1
  }

  mkdir -p "$home/bin" "$home/.agents"
  ln -s "$node_path" "$home/bin/node"
  codex_skill="$home/.codex/plugins/cache/openai-curated/superpowers/test/skills/using-superpowers/SKILL.md"
  claude_skill="$home/.claude/plugins/cache/claude-plugins-official/superpowers/test/skills/brainstorming/SKILL.md"
  mkdir -p "$(dirname "$codex_skill")" "$(dirname "$claude_skill")"
  printf '%s\n' '---' 'name: using-superpowers' 'description: Use when starting any conversation - establishes how to find and use skills' '---' '' '<EXTREMELY-IMPORTANT>' 'If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.' '</EXTREMELY-IMPORTANT>' > "$codex_skill"
  printf '%s\n' '---' 'name: brainstorming' 'description: "You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior."' '---' '' 'body' > "$claude_skill"

  printf '#!/usr/bin/env bash\nprintf "codex %%s\\n" "$*" >> "$HOME/commands.log"\nif [ "$1 $2" = "plugin list" ]; then printf "PLUGIN STATUS VERSION PATH\\nsuperpowers@openai-curated not installed  /tmp/superpowers\\n"; exit 0; fi\nif [ "$1 $2 $3" = "plugin add superpowers@openai-curated" ]; then exit 0; fi\nexit 8\n' > "$home/bin/codex"
  printf '#!/usr/bin/env bash\nprintf "claude %%s\\n" "$*" >> "$HOME/commands.log"\nif [ "$1 $2 $3" = "plugin list --json" ]; then printf "[]\\n"; exit 0; fi\nif [ "$1 $2 $3 $4 $5" = "plugin install superpowers@claude-plugins-official --scope user" ]; then exit 0; fi\nexit 8\n' > "$home/bin/claude"
  chmod +x "$home/bin/codex" "$home/bin/claude"

  output="$(
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" agents_home="$home/.agents" dry_run=0 bash -c '
      ROOT="$1"
      install_log="$2"
      tools=both
      tool_enabled() {
        case "$tools:$1" in
          both:*|codex:codex|claude:claude) return 0 ;;
          *) return 1 ;;
        esac
      }
      say() { printf "%s\n" "$*"; }
      die() { printf "error: %s\n" "$*" >&2; exit 1; }
      run() { "$@"; }
      . "$ROOT/scripts/lib/targets.sh"
      . "$ROOT/scripts/lib/logging.sh"
      . "$ROOT/scripts/lib/stack-tools.sh"
      install_superpowers
    ' sh "$ROOT" "$log"
  )"

  assert_contains "$output" "OK Install Superpowers for Codex"
  assert_contains "$output" "OK Install Superpowers for Claude Code"
  assert_contains "$output" "OK Limit Superpowers skills to manual invocation"
  commands="$(cat "$home/commands.log")"
  assert_contains "$commands" "codex plugin add superpowers@openai-curated"
  assert_contains "$commands" "claude plugin install superpowers@claude-plugins-official --scope user"
  assert_not_contains "$commands" "git clone"
  assert_not_contains "$commands" "ln -sfn"
  assert_contains "$(cat "$codex_skill")" "description: Manual Superpowers workflow only."
  assert_contains "$(cat "$claude_skill")" "description: Manual Superpowers workflow only."
  assert_contains "$(cat "$codex_skill")" "Superpowers is installed and available, but this stack does not invoke Superpowers skills automatically."
  assert_not_contains "$(cat "$codex_skill")" "Use when starting any conversation"
  assert_not_contains "$(cat "$codex_skill")" "1% chance"
  assert_not_contains "$(cat "$codex_skill")" "ABSOLUTELY MUST invoke"
  assert_not_contains "$(cat "$claude_skill")" "You MUST use this before any creative work"
}

# Verify Claude Code Caveman installs through skills, not the Claude plugin
# namespace that exposes caveman:caveman-* slash commands.
missing_caveman_uses_claude_code_skills() {
  local home="$tmp/home-caveman-claude-skills"
  local log="$home/.agents/install.log"
  local output commands
  local node_path
  node_path="$(command -v node || true)"
  [ -n "$node_path" ] || {
    printf 'node is required for this test\n' >&2
    exit 1
  }

  mkdir -p "$home/bin" "$home/.agents"
  ln -s "$node_path" "$home/bin/node"

  printf '#!/usr/bin/env bash\nprintf "npx %%s\\n" "$*" >> "$HOME/commands.log"\ncase "$*" in\n  "skills list --json --global --agent claude-code") printf "[]\\n"; exit 0 ;;\n  "skills add JuliusBrussee/caveman --yes --global --agent claude-code") exit 0 ;;\n  *) printf "unexpected npx args: %%s\\n" "$*" >&2; exit 9 ;;\nesac\n' > "$home/bin/npx"
  printf '#!/usr/bin/env bash\nprintf "claude %%s\\n" "$*" >> "$HOME/commands.log"\nif [ "$1 $2 $3" = "plugin list --json" ]; then printf "[]\\n"; exit 0; fi\nif [ "$1 $2 $3" = "plugin marketplace add" ]; then exit 0; fi\nif [ "$1 $2 $3 $4 $5" = "plugin install caveman@caveman --scope user" ]; then exit 0; fi\nexit 8\n' > "$home/bin/claude"
  chmod +x "$home/bin/npx" "$home/bin/claude"

  output="$(
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" agents_home="$home/.agents" dry_run=0 bash -c '
      ROOT="$1"
      install_log="$2"
      tools=claude
      tool_enabled() {
        case "$tools:$1" in
          both:*|codex:codex|claude:claude) return 0 ;;
          *) return 1 ;;
        esac
      }
      say() { printf "%s\n" "$*"; }
      die() { printf "error: %s\n" "$*" >&2; exit 1; }
      run() { "$@"; }
      . "$ROOT/scripts/lib/targets.sh"
      . "$ROOT/scripts/lib/logging.sh"
      . "$ROOT/scripts/lib/stack-tools.sh"
      install_caveman
    ' sh "$ROOT" "$log"
  )"

  assert_contains "$output" "OK Install Caveman skills for Claude Code"
  commands="$(cat "$home/commands.log")"
  assert_contains "$commands" "npx skills list --json --global --agent claude-code"
  assert_contains "$commands" "npx skills add JuliusBrussee/caveman --yes --global --agent claude-code"
  assert_not_contains "$commands" "claude plugin marketplace add JuliusBrussee/caveman"
  assert_not_contains "$commands" "claude plugin install caveman@caveman"
}

# Verify empty JSON helper output fails explicitly instead of looking like a
# missing install.
installed_state_helpers_reject_empty_json_output() {
  local home="$tmp/home-installed-state-empty-json"
  local log="$home/.agents/install.log"
  local output
  local node_path
  node_path="$(command -v node || true)"
  [ -n "$node_path" ] || {
    printf 'node is required for this test\n' >&2
    exit 1
  }

  mkdir -p "$home/bin" "$home/.agents"
  ln -s "$node_path" "$home/bin/node"
  printf '#!/usr/bin/env bash\nprintf "   \\n"\n' > "$home/bin/claude"
  chmod +x "$home/bin/claude"

  if output="$(
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" agents_home="$home/.agents" dry_run=0 bash -c '
      ROOT="$1"
      install_log="$2"
      say() { printf "%s\n" "$*"; }
      die() { printf "error: %s\n" "$*" >&2; exit 1; }
      . "$ROOT/scripts/lib/targets.sh"
      . "$ROOT/scripts/lib/logging.sh"
      . "$ROOT/scripts/lib/stack-tools.sh"
      claude_plugin_installed superpowers@claude-plugins-official
    ' sh "$ROOT" "$log" 2>&1
  )"; then
    printf 'empty JSON unexpectedly succeeded\n' >&2
    exit 1
  fi

  assert_contains "$output" "invalid JSON from claude plugin list: empty output"
}

# Verify Claude Desktop targets configure Context7 through the Desktop MCP config
# path without requiring the Claude Code CLI.
dry_run_prints_stack_steps_for_claude_desktop() {
  local home="$tmp/home-stack-claude-desktop"
  local output log config
  mkdir -p "$home/bin" "$home/Applications/Claude.app"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/node"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/npx"
  chmod +x "$home/bin/node" "$home/bin/npx"
  config="$home/Library/Application Support/Claude/claude_desktop_config.json"

  output="$(
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" CONTEXT7_API_KEY=test-key \
      CLAUDE_DESKTOP_APP_PATH="$home/Applications/Claude.app" \
      CLAUDE_DESKTOP_CONFIG_PATH="$config" \
      bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets claude
  )"
  log="$home/.agents/install.log"

  assert_contains "$output" "Dry run Configure Context7 for Claude Desktop"
  assert_contains "$output" "Skipped LeanCTX proxy for Claude disabled"
  assert_contains "$output" "$config"
  assert_contains "$output" "Skipped Claude Code CLI not found"
  assert_contains "$(cat "$log")" "claude_proxy=disabled"
  assert_not_contains "$(cat "$log")" "lean-ctx proxy enable"
  assert_contains "$(cat "$log")" "update_claude_desktop_config=$config server=context7"
}

# Verify users can explicitly enable Claude proxy setup when they provide the
# Anthropic API key.
dry_run_can_enable_claude_proxy() {
  local home="$tmp/home-stack-claude-proxy"
  local output log config
  mkdir -p "$home/bin" "$home/Applications/Claude.app"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/node"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/npx"
  chmod +x "$home/bin/node" "$home/bin/npx"
  config="$home/Library/Application Support/Claude/claude_desktop_config.json"

  output="$(
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" CONTEXT7_API_KEY="test-context7" \
      CLAUDE_DESKTOP_APP_PATH="$home/Applications/Claude.app" \
      CLAUDE_DESKTOP_CONFIG_PATH="$config" \
      ANTHROPIC_API_KEY="test-anthropic" \
      bash "$ROOT/scripts/install.sh" --dry-run --non-interactive --targets claude --enable-claude-proxy
  )"
  log="$home/.agents/install.log"

  assert_contains "$output" "Dry run Enable LeanCTX proxy"
  assert_contains "$output" "Dry run Configure Context7 for Claude Desktop"
  assert_contains "$(cat "$log")" "claude_proxy=enabled"
  assert_contains "$(cat "$log")" "ANTHROPIC_API_KEY=<redacted>"
  assert_contains "$(cat "$log")" "env ANTHROPIC_API_KEY=<redacted> lean-ctx proxy enable"
}

# Verify the Claude Desktop config writer preserves existing MCP servers and
# merges the managed Context7 entry.
claude_desktop_config_is_merged() {
  local home="$tmp/home-claude-desktop-merge"
  local output config node_path
  node_path="$(command -v node || true)"
  [ -n "$node_path" ] || {
    printf 'node is required for this test\n' >&2
    exit 1
  }

  mkdir -p "$home/bin" "$home/Applications/Claude.app" "$home/Library/Application Support/Claude"
  ln -s "$node_path" "$home/bin/node"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/npx"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/lean-ctx"
  chmod +x "$home/bin/npx" "$home/bin/lean-ctx"
  config="$home/Library/Application Support/Claude/claude_desktop_config.json"
  printf '{"theme":"dark","mcpServers":{"existing":{"command":"true"}}}\n' > "$config"

  output="$(
    HOME="$home" PATH="$home/bin:/usr/bin:/bin" CONTEXT7_API_KEY=test-key \
      CLAUDE_DESKTOP_APP_PATH="$home/Applications/Claude.app" \
      CLAUDE_DESKTOP_CONFIG_PATH="$config" \
      bash "$ROOT/scripts/install.sh" --non-interactive --targets claude
  )"

  assert_contains "$output" "OK Configure Context7 for Claude Desktop $config"
  assert_not_contains "$output" "Configure Context7 for Claude Code"
  "$node_path" -e '
const fs = require("fs");
const config = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
if (config.theme !== "dark") process.exit(1);
if (!config.mcpServers.existing) process.exit(2);
if (config.mcpServers.context7.command !== "npx") process.exit(3);
if (config.mcpServers.context7.env.CONTEXT7_API_KEY !== "test-key") process.exit(4);
' "$config"
}

# Run the stack-tool scenarios.
context7_credentials_required
dry_run_prints_stack_steps_for_codex
dry_run_finds_git_project_from_home
stack_command_already_exists_continues
stack_command_real_failure_still_fails
installed_state_helpers_detect_existing_tools
codex_plugin_installed_accepts_marketplace_sections
installed_state_helpers_reject_invalid_json
installed_stack_tools_are_skipped
invalid_claude_skill_json_stops_caveman_install
invalid_codex_skill_json_stops_caveman_install
malformed_codex_plugin_list_stops_superpowers_install
missing_superpowers_uses_plugin_installers
missing_caveman_uses_claude_code_skills
installed_state_helpers_reject_empty_json_output
dry_run_prints_stack_steps_for_claude_desktop
dry_run_can_enable_claude_proxy
claude_desktop_config_is_merged

printf 'install-stack-tools.sh: OK\n'
