# AI Assistant Stack

**AI Assistant Stack** is an AI assistant stack that helps reduce token usage while improving the quality and consistency of AI-assisted development.

Instead of configuring multiple tools by hand, AI Assistant Stack installs and configures a curated development stack that works together to provide better project context, access to up-to-date documentation, and reusable AI workflows.

## What Gets Installed

- **LeanCTX** for efficient project context management.
- **Context7** for live documentation and API reference retrieval.
- **Caveman** for reusable AI development skills and workflows.
- **Superpowers** for additional AI productivity enhancements.
- **Optimized AI Instruction Files** at both the global and project levels, giving AI coding assistants consistent instructions across every repository.
- **AI Instruction Project Bootstrap** installs a Git hook that automatically seeds new Git repositories with the appropriate **AGENTS.md** and/or **CLAUDE.md** project files, ensuring every project starts with an optimized AI configuration.

## Benefits

- Reduce token consumption
- Improve AI context quality
- Standardize AI behavior across projects
- Speed up new project setup
- Keep project instructions synchronized automatically
- Eliminate repetitive AI configuration
...

## Prerequisites

| Target | Required prerequisites |
|--------|------------------------|
| `codex-desktop` | Codex client or `codex` CLI |
| `codex-vscode` | Codex client or `codex` CLI, VS Code `code` CLI |
| `claude-desktop` | Claude client or `claude` CLI |
| `claude-vscode` | Claude client or `claude` CLI, VS Code `code` CLI |

If a selected prerequisite is missing, the installer stops before making
changes and prints the missing prerequisite list.

Context7 configuration requires an API key in the install environment:

```bash
export CONTEXT7_API_KEY="your-context7-api-key"
```

If `CONTEXT7_API_KEY` is missing, the installer stops before Context7
configuration and prints setup instructions.

## Installation

Users do not need to clone this repository. The bootstrap script downloads a
temporary archive, verifies it when a checksum is provided, runs the installer,
and removes the temporary files when it exits.

Install Command:

```bash
curl -fsSL https://raw.githubusercontent.com/elite-guy5/ai-assistant-stack/main/scripts/bootstrap.sh | bash
```

Installer logs are written to:

```text
~/.agents/install.log
```

## What It Installs

- LeanCTX configuration
- Context7 MCP configuration
- Caveman skill/plugin configuration
- Superpowers skill/plugin configuration
- Codex global instructions: `~/.codex/AGENTS.md`
- Codex project template: `~/.codex/AGENTS.project-template.md`
- Claude Code global instructions: `~/.claude/CLAUDE.md`
- Claude Code project template: `~/.claude/CLAUDE.project-template.md`
- Shared seeding script: `~/.agents/scripts/seed-project-instructions.sh`
- Git template hooks:
  - `~/.agents/git-template/hooks/post-checkout`
  - `~/.agents/git-template/hooks/post-merge`

The Git template hooks seed instruction files into repositories created after
installation. During interactive install, the script also offers to seed and
install managed hooks in the current repository when it is run from inside one.

## What the Markdown Files Configure

- Global `AGENTS.md` and `CLAUDE.md` files define the baseline response style,
  verification expectations, secret handling, and token-saver context
  boundaries.
- The global files tell agents to use LeanCTX for scoped code reading, search,
  AST-aware workspace analysis, and compressed shell output.
- The global files require Caveman as a compression skill for conversational
  narrative, prompt instructions, and logs while preserving code, paths, flags,
  APIs, and error output exactly.
- The global files keep Superpowers manual-only unless the user explicitly
  requests that workflow in a session.
- Project templates give each repository a local place for purpose, language,
  commands, tests, coding standards, project-specific rules, and context
  boundaries.

## Agent Stack Setup Guides

The installer follows these guides when configuring stack tools:

- [Codex agent stack setup](docs/codex-agent-stack-setup.md)
- [Claude agent stack setup](docs/claude-agent-stack-setup.md)

## Windows Stack Commands

The automated installer remains macOS-focused. On Windows, install Node.js 18
or newer, Git, VS Code, and the selected AI clients first, then run the
upstream commands below from PowerShell or from the target AI client. Commands
come from [LeanCTX](https://github.com/yvgude/lean-ctx),
[Context7](https://github.com/upstash/context7),
[Caveman](https://github.com/JuliusBrussee/caveman), and
[Superpowers](https://github.com/obra/superpowers).

Install LeanCTX:

```powershell
npm install -g lean-ctx-bin
lean-ctx onboard
lean-ctx doctor
```

Alternative LeanCTX package-manager install:

```powershell
cargo install lean-ctx
```

Install Context7 for Codex and Claude Code:

```powershell
$env:CONTEXT7_API_KEY = "your-context7-api-key"
npx ctx7 setup --codex --api-key $env:CONTEXT7_API_KEY
npx ctx7 setup --claude --api-key $env:CONTEXT7_API_KEY
```

Install Caveman:

```powershell
irm https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.ps1 | iex
npx skills add JuliusBrussee/caveman -a codex
claude plugin marketplace add JuliusBrussee/caveman
claude plugin install caveman@caveman
```

Install Superpowers from the target client.

For Codex CLI, open the plugin search interface, search for `superpowers`, and
select `Install Plugin`:

```text
/plugins
superpowers
```

For Claude Code:

```text
/plugin install superpowers@claude-plugins-official
```

Uninstall LeanCTX:

```powershell
lean-ctx uninstall
lean-ctx uninstall --dry-run
lean-ctx uninstall --keep-config
npm uninstall -g lean-ctx-bin
cargo uninstall lean-ctx
```

Uninstall Context7:

```powershell
npx ctx7 remove
npm uninstall -g ctx7
```

Uninstall Caveman:

```powershell
npx -y github:JuliusBrussee/caveman -- --uninstall
npx skills remove caveman
```

The Superpowers repository does not document a general uninstall command for
Codex or Claude Code installs. For this repository's git-clone and symlink
layout on Windows, remove the cloned repositories and linked skill folders:

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\.codex\superpowers", "$env:USERPROFILE\.agents\skills\superpowers" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\superpowers", "$env:USERPROFILE\.claude\skills\superpowers" -ErrorAction SilentlyContinue
```

## Legacy Instruction-File Install

The `--tools` flow remains available for compatibility when you only want
instruction files, templates, the seeding script, and Git hooks.

Install Codex and Claude Code instruction files and hooks without stack setup:

```bash
curl -fsSL https://raw.githubusercontent.com/elite-guy5/token-saver-setup/main/scripts/bootstrap.sh | bash -s -- --tools both
```

If you already have this repository checked out for development, you can run the
installer directly from the repository.

Install Codex and Claude Code instruction files and hooks:

```bash
bash scripts/install.sh --tools both
```

Install only Codex instruction files and hooks:

```bash
bash scripts/install.sh --tools codex
```

Install only Claude Code instruction files and hooks:

```bash
bash scripts/install.sh --tools claude
```

The installed Markdown files are:

| Selected Tool | Global File | Project Template |
|---------------|-------------|------------------|
| Codex | `~/.codex/AGENTS.md` | `~/.codex/AGENTS.project-template.md` |
| Claude Code | `~/.claude/CLAUDE.md` | `~/.claude/CLAUDE.project-template.md` |

The installed hook support files are:

- `~/.agents/scripts/seed-project-instructions.sh`
- `~/.agents/git-template/hooks/post-checkout`
- `~/.agents/git-template/hooks/post-merge`

The installer also sets:

```bash
git config --global init.templateDir ~/.agents/git-template
```

New repositories created with `git init` after installation receive the managed
template hooks automatically. Those hooks seed `AGENTS.md`, `CLAUDE.md`, or both
from the installed project templates only when neither project instruction file
already exists.

To seed an existing repository and install managed hooks into that repository's
`.git/hooks/` directory, pass `--repo`:

```bash
bash scripts/install.sh --tools both --repo /path/to/repo
```

Existing Markdown instruction files are skipped by default. Use `--overwrite`
to back up and replace existing managed target files, or use
`--overwrite-global-instructions` / `--overwrite-project-templates` to limit
replacement to one file class.

Preview the install without changing files:

```bash
bash scripts/install.sh --dry-run --non-interactive --tools both
```

## Prompted Install

Interactive install with prompts:

```bash
bash scripts/install.sh
```

Non-interactive mode requires `--tools codex`, `--tools claude`, or
`--tools both` so automation cannot silently choose a target.

## Git Hook Behavior

The installer writes managed hooks into `~/.agents/git-template/hooks/` and sets
the global Git template directory:

```bash
git config --global init.templateDir ~/.agents/git-template
```

New repositories created with `git init` receive the managed hooks. The hooks
run the shared seeding script, detect the repository root, and create the
selected project instruction files only when neither project instruction file is
already present:

| Selected Tool | Project File |
|---------------|--------------|
| Codex | `AGENTS.md` |
| Claude Code | `CLAUDE.md` |
| Both | `AGENTS.md` and `CLAUDE.md` |

Existing project instruction files stop seeding by default: if either
`AGENTS.md` or `CLAUDE.md` already exists, the hook does not add another project
template file. When overwrite is explicitly requested through the seeding
script, the old file is backed up before replacement.

If a hook already exists, the installer backs it up and writes a wrapper hook
that runs the previous hook before the managed seeding command. Managed markers
prevent duplicate hook entries when the installer is rerun.

## Current Repository Setup

To seed and install managed hooks in an existing repository:

```bash
bash scripts/install.sh --tools both --repo /path/to/repo
```

Interactive installs ask whether to apply the same setup to the current
repository when the installer is run from inside a Git worktree.

## Options

| Option | Purpose |
|--------|---------|
| `--tools codex` | Install only Codex instruction files and hooks. |
| `--tools claude` | Install only Claude Code instruction files and hooks. |
| `--tools both` | Install both instruction-file sets. |
| `--repo <path>` | Also seed and install managed hooks in an existing repo. |
| `--dry-run` | Print actions without changing files. |
| `--non-interactive` | Disable prompts; requires `--tools`. |
| `--overwrite` | Back up and replace existing target files. |
| `--overwrite-global-instructions` | Back up and replace global instruction files. |
| `--overwrite-project-templates` | Back up and replace project templates. |
| `--uninstall` | Remove installer-managed files and hook entries. |

## Uninstall

Preview uninstall:

```bash
bash scripts/install.sh --dry-run --uninstall
```

Run uninstall:

```bash
bash scripts/install.sh --non-interactive --uninstall
```

Uninstall removes only artifacts recorded by this installer: managed global
instruction files, project templates, the shared seeding script, Git template
hooks, managed current-repo hook entries, and this installer's
`init.templateDir` setting. It does not delete repository-local `AGENTS.md` or
`CLAUDE.md` files after they have been created.

### Stack Tool Uninstall Commands

These commands come from the upstream tool repositories where the upstream
project documents an uninstall flow. They do not uninstall Codex, Claude,
VS Code, Node.js, npm, or Homebrew.

LeanCTX ([yvgude/lean-ctx](https://github.com/yvgude/lean-ctx)):

```bash
lean-ctx uninstall
lean-ctx uninstall --dry-run
lean-ctx uninstall --keep-config
curl -fsSL https://leanctx.com/install.sh | sh -s -- --uninstall
```

If LeanCTX was installed through a package manager, run the matching package
manager uninstall after `lean-ctx uninstall` reports what remains:

```bash
brew uninstall lean-ctx
cargo uninstall lean-ctx
npm uninstall -g lean-ctx-bin
pi uninstall npm:pi-lean-ctx
```

Context7 ([upstash/context7](https://github.com/upstash/context7)):

```bash
npx ctx7 remove
npm uninstall -g ctx7
```

Caveman ([JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)):

```bash
npx -y github:JuliusBrussee/caveman -- --uninstall
npx skills remove caveman
```

Superpowers ([obra/superpowers](https://github.com/obra/superpowers)):

The Superpowers repository does not document a general uninstall command for
Codex or Claude Code installs. For the git-clone and symlink layout this
repository creates, remove the cloned repository and symlinks:

```bash
rm -rf ~/.codex/superpowers ~/.agents/skills/superpowers
rm -rf ~/.claude/superpowers ~/.claude/skills/superpowers
```

Run the installer uninstall command as well when you want to remove the
instruction files, templates, seeding script, and managed Git hooks:

```bash
bash scripts/install.sh --non-interactive --uninstall
```

## Remote Bootstrap

The bootstrap script downloads a pinned archive, verifies its checksum, and
executes the local Bash installer from that archive.

```bash
bash scripts/bootstrap.sh --dry-run --non-interactive --tools both
```

Update the pinned commit and checksum together before publishing a new remote
installer snapshot.

## Development

Run syntax checks:

```bash
bash -n scripts/*.sh tests/*.sh
```

Run the regression suite:

```bash
for test in tests/*.sh; do bash "$test"; done
```

There is no compiled build and no project-native formatter configured. Preserve
the existing shell and Markdown style when editing files.

## Optional Manual Codex Environment Setup Guide

The following guide is a manual reference for the larger local environment this
installer can support. The target-aware installer follows the stack setup guides
above; use the commands below only when diagnosing or configuring a machine by
hand.

### Component Overview

The full local environment can include these external systems:

- LeanCTX as a local context-isolation engine for shell output compression,
  workspace mapping, and AST-aware context scoping.
- A Codex CLI symlink that exposes the Codex Desktop application binary from
  the terminal.
- MCP servers for LeanCTX, Context7, and Obsidian.
- Behavioral skills such as Caveman and Superpowers.

### Phase 1: Terminal Dependencies and Host Utilities

With Codex already installed, expose its binary globally:

```bash
sudo ln -s /Applications/Codex.app/Contents/Resources/codex /usr/local/bin/codex
codex --version
```

Install LeanCTX manually:

```bash
brew tap yvgude/lean-ctx
brew install lean-ctx
which lean-ctx
```

### Phase 2: Context7

Create an account at `https://context7.com/`, copy the API key, and run:

```bash
npx ctx7 setup
```

When prompted to write system-level configuration files automatically, prefer
explicit review of generated configuration before accepting changes.

### Phase 3: Codex Configuration

Open the Codex config:

```bash
code ~/.codex/config.toml
```

The guide uses this structure:

```toml
[features]
hooks = true
js_repl = false

[mcp_servers.context7]
command = "npx"
args = ["-y", "@upstash/context7-mcp@latest"]

[mcp_servers.lean-ctx]
command = "lean-ctx"
args = ["serve"]
```

After editing, quit and reopen Codex, then open the Plugins page to verify the
configuration parses correctly.

### Phase 4: Behavioral Skills

Install runtime skills manually:

```bash
npx skills add JuliusBrussee/caveman -a codex
npx skills add superpowers -a codex
```

### Phase 5: Verification Diagnostics

Verify external tools manually:

```bash
lean-ctx status
```

Then confirm:

- Codex launches successfully.
- No configuration errors appear.
- MCP servers initialize correctly.
- Plugins load normally.
- LeanCTX reports a healthy status.

## Requirements

- macOS
- Bash
- Git
- `curl` or `wget` only when using `scripts/bootstrap.sh`

The legacy instruction-file installer path does not require a JavaScript
runtime. Target-aware stack setup invokes upstream `npx` commands for some
optional tools.
