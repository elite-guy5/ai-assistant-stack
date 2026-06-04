# Overview
This document walks you through configuring an optimized AI coding environment. The goal is to reduce token waste, improve model response quality, and keep costs in check across agentic coding sessions.

# One-Command Install

Run the installer for your platform. It downloads this repo, asks which optional tools to install, then installs the shared instruction templates, project seeding hook, and AI ignore optimizer.

**macOS / Linux / WSL**

~~~sh
curl -fsSL https://raw.githubusercontent.com/elite-guy5/token-saver-setup/main/scripts/bootstrap.sh | bash
~~~

**Windows PowerShell**

~~~powershell
irm https://raw.githubusercontent.com/elite-guy5/token-saver-setup/main/scripts/bootstrap.ps1 | iex
~~~

# Uninstall

**macOS / Linux / WSL**

~~~sh
curl -fsSL https://raw.githubusercontent.com/elite-guy5/token-saver-setup/main/scripts/bootstrap.sh | bash -s -- --uninstall
~~~

**Windows PowerShell**

~~~powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/elite-guy5/token-saver-setup/main/scripts/bootstrap.ps1))) -Uninstall
~~~

The installer prompts in this order:

- AI apps to configure. Options: `claude`, `codex`, `gemini`, `cursor`, `opencode`, `openclaw`, `copilot`, or `all`. Default: `claude,codex`.
- Whether to install RTK for the selected AI apps. Options: `y` / `n`. Default: `y`.
- Whether to install Caveman for the selected AI apps. Options: `y` / `n`. Default: `y`.
- Whether to install global instruction files for the selected AI apps. Options: `y` / `n`. Default: `y`.
- Whether to install project instruction files for the selected AI apps. Options: `y` / `n`. Default: `y`.
- Whether to install AI ignore boundaries for the selected AI apps. Options: `y` / `n`. Default: `y`.

Useful non-interactive examples:

~~~sh
curl -fsSL https://raw.githubusercontent.com/elite-guy5/token-saver-setup/main/scripts/bootstrap.sh | bash -s -- --non-interactive
curl -fsSL https://raw.githubusercontent.com/elite-guy5/token-saver-setup/main/scripts/bootstrap.sh | bash -s -- --non-interactive --skip-rtk --skip-caveman
curl -fsSL https://raw.githubusercontent.com/elite-guy5/token-saver-setup/main/scripts/bootstrap.sh | bash -s -- --dry-run
curl -fsSL https://raw.githubusercontent.com/elite-guy5/token-saver-setup/main/scripts/bootstrap.sh | bash -s -- --uninstall
curl -fsSL https://raw.githubusercontent.com/elite-guy5/token-saver-setup/main/scripts/bootstrap.sh | bash -s -- --uninstall --non-interactive --uninstall-components "all available"
~~~

~~~powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/elite-guy5/token-saver-setup/main/scripts/bootstrap.ps1))) -NonInteractive
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/elite-guy5/token-saver-setup/main/scripts/bootstrap.ps1))) -NonInteractive -SkipRtk -SkipCaveman
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/elite-guy5/token-saver-setup/main/scripts/bootstrap.ps1))) -DryRun
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/elite-guy5/token-saver-setup/main/scripts/bootstrap.ps1))) -Uninstall
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/elite-guy5/token-saver-setup/main/scripts/bootstrap.ps1))) -Uninstall -NonInteractive -UninstallComponents "all available"
~~~

If you cloned the repo locally, run:

~~~sh
bash scripts/install.sh
~~~

~~~powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
~~~

Installer flags:

- `--non-interactive` / `-NonInteractive` - use defaults and do not prompt.
- `--dry-run` / `-DryRun` - preview actions.
- `--project-scope <path>` / `-ProjectScope <path>` - set the project directory for project seeding instructions.
- `--overwrite` / `-Overwrite` - replace managed files instead of skipping them.
- `--overwrite-global-instructions` / `-OverwriteGlobalInstructions` - replace existing `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`; default is to skip existing global instruction files.
- `--overwrite-project-templates` / `-OverwriteProjectTemplates` - replace existing `~/.claude/CLAUDE.project-template.md` and `~/.codex/AGENTS.project-template.md`; default is to skip existing project template files.
- `--uninstall` / `-Uninstall` - remove selected installed components.
- `--uninstall-components <list>` / `-UninstallComponents <list>` - comma-separated components to remove, or `all available`.
- `--skip-rtk` / `-SkipRtk` - skip RTK install/init.
- `--skip-caveman` / `-SkipCaveman` - skip Caveman install.
- `--ai-apps <list>` / `-AiApps <list>` - comma-separated AI apps to configure. Default: `claude,codex`.
- `--assets <list>` / `-Assets <list>` - comma-separated assets to install. Default: `all`.
- `--rtk-agents <list>` / `-RtkAgents <list>` - comma-separated RTK agents.
- `--rtk-mode <mode>` / `-RtkMode <mode>` - RTK setup mode, default `auto`.
- `--caveman-args <args>` / `-CavemanArgs <args>` - pass extra flags to Caveman.
- `--caveman-mode <mode>` / `-CavemanMode <mode>` - persistent Caveman default mode, default `ultra`.

# Recommended Layered Configuration

Apply all four layers for maximum effect in a production coding environment:

~~~
Layer 1 — Shell Proxy (rtk)
  └── Filters CLI outputs before they enter the prompt history
      Intercepts Bash tool calls and compresses output before it enters the prompt

Layer 2 — Prompt Simplification (caveman-skill)
  └── Forces sessions into a minimal, verbose-free response mode.
      Reduces output bloat in long sessions.

Layer 3 - Global Instruction Files (CLAUDE.md + AGENTS.md)
  └── Keeps personal behavior rules consistent across tools
      Claude Code uses ~/.claude/CLAUDE.md
      Codex uses ~/.codex/AGENTS.md
      RTK guidance is included by reference instead of pasted inline

Layer 4 - Project Instruction Seeding
  └── Creates project-local CLAUDE.md and AGENTS.md when missing
      Runs from a Claude Code SessionStart hook
      Uses templates instead of hand-copying instructions per repo

Layer 5 - AI Ignore Boundaries
  └── Keeps token-heavy and sensitive files out of agent context by default
      Maintains .gitignore, .codexignore, and .claude/settings.local.json
      Blocks secrets, lockfiles, logs, coverage, build output, dependencies, local databases, and AI-only binary assets
~~~

**Key principle:** Configure hooks at the shell level rather than relying on natural language prompts to instruct the agent to "compress output." Prompt-level instructions consume tokens and achieve only 70–85% compliance. Shell hooks achieve 100% coverage with zero token overhead.


# Repo Files

This repo includes the files needed to install and maintain the instruction setup:

- `scripts/bootstrap.sh` - remote macOS/Linux/WSL bootstrapper.
- `scripts/bootstrap.ps1` - remote Windows PowerShell bootstrapper.
- `scripts/install.sh` - macOS/Linux/WSL installer for tools, global files, templates, and the Claude Code SessionStart hook.
- `scripts/install.ps1` - native Windows PowerShell installer.
- `scripts/seed-project-instructions.sh` - shell project seeding hook.
- `scripts/seed-project-instructions.ps1` - PowerShell project seeding hook.
- `scripts/optimize-ai.sh` - shell project ignore optimizer for `.gitignore`, `.codexignore`, and `.claude/settings.local.json`.
- `scripts/optimize-ai.ps1` - PowerShell project ignore optimizer.
- `templates/CLAUDE.global.md` - global Claude Code instruction template.
- `templates/AGENTS.global.md` - global Codex instruction template.
- `templates/CLAUDE.project-template.md` - project-local Claude Code template.
- `templates/AGENTS.project-template.md` - project-local Codex template.
- `config/claude-settings-sessionstart.json` - standalone macOS/Linux/WSL Claude Code hook snippet.
- `config/claude-settings-sessionstart.windows.json` - standalone Windows PowerShell Claude Code hook snippet.

Installer behavior:

- Creates missing target files.
- Writes a machine-readable manifest to `~/.agents/install_manifest.json`.
- Records managed created or modified files, directories, settings entries, generated tool references, and installer-owned versus user-owned artifacts.
- Skips existing global Claude/Codex instruction files unless the global-instruction overwrite option is selected.
- Skips existing managed files when they differ unless an overwrite option is selected.
- Installs the seeding scripts to `~/.agents/scripts/`.
- Installs the AI ignore optimizer scripts to `~/.agents/scripts/`.
- Installs RTK globally, then auto-detects installed agents and runs per-agent RTK init commands when needed.
- Writes persistent Caveman config, runs the unified Caveman installer, and adds per-agent fallbacks for detected non-Claude agents.
- Adds the Claude Code `SessionStart` hook if it is missing.
- When a project is seeded, updates `.gitignore`, `.codexignore`, and `.claude/settings.local.json` with token-bloat exclusions.
- Use `--overwrite` only when you intentionally want to replace existing target files.

Uninstall behavior:

- Uses `~/.agents/install_manifest.json` as the source of truth when available.
- Deletes files only when the manifest records them as installer-created full files.
- Preserves user-owned `CLAUDE.md`, `AGENTS.md`, settings files, and other user-owned files unless a removable managed section is recorded.
- Falls back to legacy cleanup rules when the manifest is missing or has no records for a selected component, and reports that fallback.
- Prompts for components with `global-instructions`, `reset-global-instructions`, `project-instructions`, `project-templates`, `seeding`, `ignore-optimizer`, `rtk`, `caveman`, or `all available`.
- Interactive uninstall first asks whether to reset all instruction files or only project instruction sections.
- `global-instructions` removes manifest-owned instruction files, or preserves user-owned instruction files.
- `reset-global-instructions` explicitly blanks `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`.
- `project-instructions` scans first-level projects in the configured project directory and removes managed Token-Saver and workflow sections from project-local `CLAUDE.md` and `AGENTS.md`; it never deletes those files.
- `project-templates` removes `~/.claude/CLAUDE.project-template.md` and `~/.codex/AGENTS.project-template.md`.
- `seeding` removes token-saver seeding scripts and matching Claude `SessionStart` hooks.
- `ignore-optimizer` removes token-saver optimizer scripts.
- `rtk` runs RTK uninstall commands for detected agents and removes installer-managed `RTK.md` files.
- `caveman` runs Caveman uninstall commands, removes Caveman config, known Claude settings entries, known Codex config entries, skills, and Gemini extension when available.
- Uninstall never writes `.new` files.

# AI Ignore Optimization

The seeding hook runs the optimizer for first-level projects inside your configured project directory. You can also run it manually from a project root:

~~~sh
bash ~/.agents/scripts/optimize-ai.sh
~~~

~~~powershell
powershell -NoProfile -ExecutionPolicy Bypass -File $HOME\.agents\scripts\optimize-ai.ps1
~~~

The optimizer adds managed blocks for:

- Secrets: `.env`, `.env.*`.
- Lockfiles: `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `poetry.lock`.
- Build and cache output: `dist/`, `build/`, `out/`, `.next/`, `.nuxt/`.
- Dependencies and virtual environments: `node_modules/`, `vendor/`, `.venv/`, `venv/`.
- Logs, coverage, and local data: `*.log`, `coverage/`, `.nyc_output/`, `*.db`, `*.sqlite`, `*.sqlite3`.
- AI-only binary and media exclusions in `.codexignore`: images, archives, audio, video, and PDFs.

The `.gitignore` block intentionally avoids broad image, PDF, and media patterns because many repositories need source assets committed. Those file types are added to `.codexignore` instead so agents avoid reading them while Git can still track intentional assets.

# Pre-Reqs
Assuming you have your AI tool installed, you will need Node.js if you choose to install Caveman because the Caveman installer uses `npx`. Python is not required by this repo's installer. Open your terminal in your home directory, usually `~` on macOS/Linux/WSL or `%USERPROFILE%` on Windows.

### 1. Node.js aks npm

GitHub Link: [https://github.com/npm/cli](https://github.com/npm/cli)

**macOS / Linux**
- Pres cmd + space and search Terminal 
- Run the following in your home directory
~~~sh
#homebrew
brew install node
~~~

**Windows**
- Open Command Prompt or PowerShell as an Administrator (Right-click -> Run as Administrator).
- Run the following command:
~~~sh
# Download and install Chocolatey:
powershell -c "irm https://community.chocolatey.org/install.ps1|iex"

# Download and install Node.js:
choco install nodejs
~~~

|

|

# Layer 1: rtk (Rust Token Killer)
GitHub Link: [GitHub: rtk-ai/rtk](https://github.com/rtk-ai/rtk)

Intercepts CLI tool calls (e.g., `git diff`, `cargo test`, `docker ps`) and filters output before it enters the prompt. Achieves **60–92% token reduction** on common commands with under 10ms latency.

> **Important:** rtk only intercepts Bash tool calls. Native agent tools (`Read`, `Grep`, `Glob`) bypass the hook — use `cat`, `rg`, `find` via Bash if you need rtk filtering on those operations.

### Manual install

**macOS / Linux:**
- Run the following in your home directory
~~~sh
brew install rtk
~~~

**Windows (PowerShell):**
- Open Command Prompt or PowerShell as an Administrator (Right-click -> Run as Administrator).
~~~powershell
winget install rtk-ai.rtk
~~~

> **Windows note:** Install [WSL 2](https://learn.microsoft.com/en-us/windows/wsl/install) before proceeding. The Bash hook that intercepts shell commands requires a Unix shell. Without WSL, the hook is unavailable and rtk falls back to injecting instructions into `CLAUDE.md`, which increases prompt tokens rather than reducing them.

### Step 2: Initialize (Global Hook)

**macOS / Linux / WSL:**
- Run the following in your home directory
~~~sh
rtk init --global
~~~

**Windows (limited mode, no hook):**
- Open Command Prompt or PowerShell as an Administrator (Right-click -> Run as Administrator).
~~~sh
rtk init --global
~~~

This injects a pre-tool Bash hook so commands like `git status` are automatically rewritten to `rtk git status` without any further configuration. On Windows without WSL, the hook is unavailable; RTK falls back to prompt-level guidance and explicit `rtk <cmd>` usage. Use WSL for transparent shell rewrite.

The installer uses this same pattern automatically: global setup first, then detected-agent fallback setup. If you need to run a fallback manually:
~~~sh
# 1. Install for your AI tool
rtk init -g                     # Claude Code / Copilot (default)
rtk init -g --gemini            # Gemini CLI
rtk init -g --codex             # Codex (OpenAI)
rtk init -g --agent cursor      # Cursor
rtk init --agent opencode       # OpenCode
rtk init --agent openclaw       # OpenClaw
rtk init --agent pi             # Pi
rtk init --agent windsurf       # Windsurf
rtk init --agent cline          # Cline / Roo Code
rtk init --agent kilocode       # Kilo Code
rtk init --agent antigravity    # Google Antigravity
rtk init --agent hermes         # Hermes

# 2. Restart your AI tool, then test
git status  # Automatically rewritten to rtk git status
~~~

### Step 3: VS Code Extension

Open the **Extensions** tab in VS Code (`Ctrl+Shift+X` / `Cmd+Shift+X`), search **rtk inspector**, and install the extension by **PeterMEFrandsen**.

|

|
# Layer 2: Caveman Skill (Claude Code)
GitHub Link: [GitHub: juliusbrussee/caveman](https://github.com/juliusbrussee/caveman)

Adds a `/caveman` slash command that forces Claude Code into a minimal, verbose-free response mode. Reduces output bloat in long sessions.

The installer writes `~/.config/caveman/config.json` with `defaultMode` set to `ultra`, runs the upstream unified Caveman installer with `--all`, and adds per-agent fallback installs for detected non-Claude agents where needed. Some agents still require per-session activation if their native integration does not support always-on hooks.

### Manual install

**macOS / Linux / WSL:**
- Run the following in your home directory
~~~sh
curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash
~~~

**Windows (PowerShell):**
- Open Command Prompt or PowerShell as an Administrator (Right-click -> Run as Administrator).
~~~sh
irm https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.ps1 | iex
~~~

If the global install doesn't work you can add it per AI tool 
~~~sh
npx skills add JuliusBrussee/caveman -a antigravity
npx skills add JuliusBrussee/caveman -a codex
claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman
gemini extensions install https://github.com/JuliusBrussee/caveman
~~~
|

|
# Layer 3: Global Instruction Files

Use global instruction files for personal defaults that should apply across repositories. The repo versions live in:

- `templates/CLAUDE.global.md`
- `templates/AGENTS.global.md`

Installed locations:

- Claude Code: `~/.claude/CLAUDE.md`
- Codex: `~/.codex/AGENTS.md`

Keep these files concise. Put repository-specific commands, conventions, and gotchas in project-local instruction files instead.

### Shared global sections

Both global files now use the same core structure:

- **Response Style:** professional, neutral, concise, main conclusion first, no filler, no emojis, no sycophantic openers.
- **Reasoning and Clarification:** challenge weak assumptions, ask clarifying questions when needed, and verify APIs, versions, flags, commit SHAs, and package names before asserting them.
- **Skill Usage:** Superpowers skills should auto-run only for software development work, not ordinary questions, local troubleshooting, install checks, or process inspection unless explicitly requested.
- **Software Development Guidelines:** think before coding, keep changes simple and surgical, define verifiable goals, use plan mode for non-trivial work, use subagents when useful, and pause on hacky non-trivial changes before broad refactors.
- **Memory & Knowledge:** use native agent memory for recall, the Obsidian vault for long-form human and agent knowledge, and automatic session logs or remember-style tooling for session journal data.

### RTK include

RTK creates and manages its own reference file when installed and initialized. Keep global instruction files small by referencing that installed RTK file instead of copying RTK guidance into this repo.

- Claude Code ends with `@RTK.md`
- Codex has an **RTK Usage** section that points to the RTK reference file under the current user's home directory.

In `templates/AGENTS.global.md`, this is stored as:

~~~md
@{{HOME}}/.codex/RTK.md
~~~

The installer replaces `{{HOME}}` with the current user's actual home directory when writing `~/.codex/AGENTS.md`. This repo does not install `RTK.md`; run `rtk init` first so RTK creates the referenced file.

This keeps global instruction files smaller while preserving the token-saving shell guidance.

|

|

# Layer 4: Project Instruction Seeding

Use project-local instruction files for repository-specific details. Repo templates:

- `templates/CLAUDE.project-template.md`
- `templates/AGENTS.project-template.md`

Installed locations:

- Claude Code template: `~/.claude/CLAUDE.project-template.md`
- Codex template: `~/.codex/AGENTS.project-template.md`

Each template includes:

- Project purpose, language/framework, and key entry points.
- Build, test, lint, and run commands.
- Repo-specific conventions and gotchas.
- A development workflow section that defers to Superpowers for relevant software development work.
- A precedence note: project-local instructions override skills where they conflict.
- A reminder that durable learnings belong in memory or the Obsidian vault, not in project instruction files.

### Seeding hook

The seeding hook creates project-local instruction files when they are missing.

Repo script:

~~~sh
scripts/seed-project-instructions.sh
~~~

Installed script:

~~~sh
~/.agents/scripts/seed-project-instructions.sh
~/.agents/scripts/seed-project-instructions.ps1
~~~

Behavior:

- Only runs for projects under `~/Documents` by default.
- Override the project directory with `PROJECT_SCOPE=/path/to/projects`.
- Ignores hidden top-level folders.
- Detects the first project directory below the configured project directory.
- Creates `CLAUDE.md` from `~/.claude/CLAUDE.project-template.md` if missing.
- Creates `AGENTS.md` from `~/.codex/AGENTS.project-template.md` if missing.
- Does not overwrite existing project instruction files.
- Supports dry runs with `DRY_RUN=1`.

Claude Code hook entry in `~/.claude/settings.json`. Standalone repo snippets are in `config/claude-settings-sessionstart.json` and `config/claude-settings-sessionstart.windows.json`.

~~~json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$HOME/.agents/scripts/seed-project-instructions.sh\"",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
~~~

Manual test:

~~~sh
DRY_RUN=1 bash ~/.agents/scripts/seed-project-instructions.sh ~/Documents/example-project
~~~
