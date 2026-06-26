# Token Saver Setup

Installer and project seeding scripts for token-efficient AI agent workspaces.

This repository is not a general Apple Silicon setup checklist. It is the
automation layer that installs and maintains AI-agent instruction files,
project templates, Claude seeding hooks, RTK/Caveman helper configuration, and
common ignore boundaries for Claude, Codex, and related tools.

## What It Does

- Installs global instruction files:
  - `~/.claude/CLAUDE.md`
  - `~/.codex/AGENTS.md`
- Installs project instruction templates:
  - `~/.claude/CLAUDE.project-template.md`
  - `~/.codex/AGENTS.project-template.md`
- Installs project seeding scripts under `~/.agents/scripts/`.
- Wires a Claude `SessionStart` hook so new sessions can seed project-local
  `CLAUDE.md` and `AGENTS.md` files when they are missing.
- Installs or initializes optional RTK integration for selected AI apps.
- Writes Caveman default configuration and can run legacy Caveman installers
  when explicitly allowed.
- Installs AI ignore boundary helpers for generated files, secrets,
  dependencies, logs, coverage, local databases, and binary assets.
- Records installer-owned artifacts in `~/.agents/install_manifest.json` for
  safer uninstall behavior.

## Requirements

- macOS, Linux, or Windows PowerShell environment.
- Bash for `scripts/install.sh`.
- PowerShell 7+ for `scripts/install.ps1` on Windows or parity checks.
- Node for structured JSON edits to Claude settings and install manifests.
- Optional: Homebrew or an existing `rtk` binary for RTK setup.
- Optional: `expect` for interactive prompt regression tests.

## Quick Start

Preview the default install without changing files:

```bash
bash scripts/install.sh --dry-run --non-interactive
```

Run the default shell installer:

```bash
bash scripts/install.sh
```

Run the PowerShell installer:

```powershell
pwsh -NoProfile -File ./scripts/install.ps1
```

Use a narrower project scope for project seeding:

```bash
bash scripts/install.sh --project-scope "$HOME/Documents/git"
```

## One-Command Install

Use these commands when installing from the published pinned snapshot instead
of a local clone.

Shell:

```bash
curl -fsSL https://raw.githubusercontent.com/elite-guy5/token-saver-setup/49253c77fb7b32786c6d63e89d38ea763310a25a/scripts/bootstrap.sh | bash
```

PowerShell:

```powershell
irm https://raw.githubusercontent.com/elite-guy5/token-saver-setup/49253c77fb7b32786c6d63e89d38ea763310a25a/scripts/bootstrap.ps1 | iex
```

Non-interactive shell install:

```bash
curl -fsSL https://raw.githubusercontent.com/elite-guy5/token-saver-setup/49253c77fb7b32786c6d63e89d38ea763310a25a/scripts/bootstrap.sh | bash -s -- --non-interactive
```

Remote uninstall:

```bash
curl -fsSL https://raw.githubusercontent.com/elite-guy5/token-saver-setup/49253c77fb7b32786c6d63e89d38ea763310a25a/scripts/bootstrap.sh | bash -s -- --uninstall
```

## Remote Bootstrap

The bootstrap scripts are thin entry points. They download a pinned archive,
verify its checksum, and then execute the installer from that archive.

Shell:

```bash
bash scripts/bootstrap.sh --dry-run
```

PowerShell:

```powershell
pwsh -NoProfile -File ./scripts/bootstrap.ps1 -DryRun
```

Update the pinned commit and checksum in the bootstrap scripts together when
publishing a new remote installer snapshot.

## Main Options

Shell options use long flags. PowerShell uses the same names in PascalCase.

| Purpose | Shell |
|---------|-------|
| Non-interactive defaults | `--non-interactive` |
| Preview actions | `--dry-run` |
| Set project seed scope | `--project-scope <path>` |
| Overwrite managed files | `--overwrite` |
| Overwrite global instructions | `--overwrite-global-instructions` |
| Overwrite project templates | `--overwrite-project-templates` |
| Skip RTK | `--skip-rtk` |
| Skip Caveman | `--skip-caveman` |
| Select AI apps | `--ai-apps claude,codex` |
| Select asset groups | `--assets rtk,caveman,global-instructions,project-instructions,ai-ignore-boundaries` |
| Select Caveman mode | `--caveman-mode ultra` |
| Permit legacy remote installers | `--allow-unverified-downloads` |
| Uninstall | `--uninstall` |
| Uninstall selected components | `--uninstall-components <list>` |

By default, unverified RTK and Caveman remote fallback commands are skipped.
Use `--allow-unverified-downloads` only when you intentionally accept those
legacy remote installer paths.

## Components

### Global Instructions

Templates in `templates/*.global.md` install to the user's Claude and Codex
global instruction locations. Existing files are skipped by default unless an
overwrite flag is provided.

### Project Templates

Templates in `templates/*.project-template.md` install to the user's Claude and
Codex template locations. The seeding hook uses these templates to create
project-local instruction files when missing.

### Project Seeding

`scripts/seed-project-instructions.sh` and
`scripts/seed-project-instructions.ps1` identify the first-level project under
`PROJECT_SCOPE` and create missing `CLAUDE.md` and `AGENTS.md` files from the
installed templates.

The shell seeder also invokes `optimize-ai.sh` when available so local ignore
boundaries are present.

### AI Ignore Boundaries

`scripts/optimize-ai.*` maintains common token-bloat exclusions in:

- `.gitignore`
- `.codexignore`
- `.claude/settings.local.json`

It skips symlinked project roots and symlinked managed targets.

### RTK

The installer can initialize RTK for selected AI apps, disable RTK telemetry,
and wire the Claude `PreToolUse` hook for `rtk hook claude`.

### Caveman

The installer writes `~/.config/caveman/config.json` with the selected default
mode. Legacy Caveman install commands require `--allow-unverified-downloads`.

## Uninstall

Preview uninstall:

```bash
bash scripts/install.sh --dry-run --uninstall
```

Non-interactive uninstall of all available components:

```bash
bash scripts/install.sh --non-interactive --uninstall
```

Target selected components:

```bash
bash scripts/install.sh --uninstall --uninstall-components project-templates,seeding
```

Supported component names include:

- `global-instructions`
- `reset-global-instructions`
- `project-instructions`
- `project-templates`
- `seeding`
- `ignore-optimizer`
- `rtk`
- `caveman`

When the install manifest exists, uninstall uses it to distinguish
installer-created artifacts from user-owned files. Legacy fallback cleanup is
scoped to known managed paths.

## Tests

Run the full shell test set:

```bash
for test in tests/*.sh; do bash "$test"; done
```

Common focused checks:

```bash
bash tests/install-dry-run.sh
bash tests/security-regression.sh
bash tests/install-visible-output.sh
bash tests/install-uninstall-prompt.sh
bash tests/ai-ignore-smoke.sh
bash tests/rtk-claude-hook.sh
```

Useful syntax checks:

```bash
bash -n scripts/*.sh tests/*.sh
```

PowerShell parser check:

```powershell
pwsh -NoProfile -Command '$errors = $null; foreach ($file in Get-ChildItem scripts/*.ps1) { $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors); if ($errors.Count) { $errors; exit 1 } }'
```

## Safety Model

- Existing global instructions and project templates are skipped by default.
- Overwrites require explicit flags.
- Bootstrap archives are checksum verified before execution.
- Symlinked project roots and managed ignore targets are not written through.
- `.env` files and generated dependency/build artifacts are excluded from
  agent context by default.
- Installer actions are reported in sections so skipped files and warnings stay
  visible.
