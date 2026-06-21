# Template Agent Injector Slimdown Design

## Goal

Reduce the repository to the smallest installer surface that still supports:

- global instruction installation for Claude and Codex
- project template installation for Claude and Codex
- the Claude `SessionStart` hook that launches project seeding
- project seeding that injects local `CLAUDE.md` and `AGENTS.md` files from the installed templates
- uninstall for those retained pieces only

Everything else in the current installer stack is out of scope and should be removed.

## In Scope

Retain these behaviors:

- Write `~/.claude/CLAUDE.md` from `templates/CLAUDE.global.md`.
- Write `~/.codex/AGENTS.md` from `templates/AGENTS.global.md`.
- Write `~/.claude/CLAUDE.project-template.md` from `templates/CLAUDE.project-template.md`.
- Write `~/.codex/AGENTS.project-template.md` from `templates/AGENTS.project-template.md`.
- Install `~/.agents/scripts/seed-project-instructions.sh` and `~/.agents/scripts/seed-project-instructions.ps1`.
- Add the Claude `SessionStart` hook that invokes the seeding script.
- Keep the seeding script bounded to the configured project scope.
- Keep uninstall support for the retained files, scripts, and hook wiring.

## Out of Scope

Remove these behaviors and their related CLI flags, prompts, manifest entries, report rows, and tests:

- RTK installation, initialization, verification, and uninstall
- Caveman installation, configuration, fallback installs, and uninstall
- AI ignore optimizer installation and uninstall
- project ignore boundary management
- any prompts that only apply to removed features
- any documentation or example commands that only apply to removed features
- any installer code paths that only support removed features

## Intended User Experience

The retained installer should behave as a focused instruction bootstrapper:

1. Install the global instruction files for Claude and Codex.
2. Install the project template files used by the seeding hook.
3. Install the seeding scripts into `~/.agents/scripts/`.
4. Wire Claude `SessionStart` so new sessions trigger seeding automatically.
5. On uninstall, remove only the retained artifacts and leave unrelated user files alone.

The installer should no longer present choices for RTK, Caveman, AI ignore optimization, or any other removed subsystem.

## Architecture

### Bootstrap scripts

`scripts/bootstrap.sh` and `scripts/bootstrap.ps1` remain as thin remote entrypoints.
They continue to download the pinned archive and hand off to the local installer.
They should not contain feature-specific logic beyond forwarding the install/uninstall request.

### Installer scripts

`scripts/install.sh` and `scripts/install.ps1` become the canonical implementation for:

- global instruction install
- project template install
- seeding hook install
- retained-piece uninstall

The installer should keep existing safety behavior for the retained files:

- skip existing files by default when overwrite is not requested
- preserve user-owned files unless explicitly targeted by the retained uninstall logic
- support dry run for the remaining install and uninstall actions

### Seeding scripts

`scripts/seed-project-instructions.sh` and `scripts/seed-project-instructions.ps1` remain the runtime injector.
They should:

- resolve the configured project scope
- identify the first-level project under that scope
- create `CLAUDE.md` and `AGENTS.md` only when missing
- use the installed project templates as the source of truth
- exit without changes when the current path is outside scope or unsafe

The seeding scripts should not perform AI ignore optimization or any other secondary setup.

## Uninstall Model

Uninstall remains supported, but only for retained pieces:

- global instruction files
- project template files
- seeding scripts
- Claude `SessionStart` hook wiring

Uninstall must not attempt to remove RTK, Caveman, optimizer state, or any other removed subsystem because those subsystems will no longer exist in the trimmed installer.

If a manifest exists, uninstall should use it as the source of truth for the retained artifacts.
If the manifest is missing or incomplete, legacy cleanup should be limited strictly to the retained artifacts.

## CLI Surface

Keep only the flags required for the retained behavior:

- non-interactive mode
- dry run
- overwrite
- overwrite-global-instructions
- overwrite-project-templates
- uninstall
- uninstall-components, limited to the retained uninstall targets
- project scope

Remove flags that only apply to removed features, including RTK, Caveman, AI apps, assets, and unverified-download overrides.

## Testing Strategy

Update tests so they cover only the retained surface:

- global instruction install
- project template install
- seeding hook install
- seeding script runtime behavior
- uninstall of retained artifacts
- dry-run coverage for the retained paths
- shell and PowerShell parity for retained paths

Remove or rewrite tests that exist only for RTK, Caveman, or AI ignore optimization.

## Acceptance Criteria

The change is complete when:

- the installer no longer exposes RTK, Caveman, or AI ignore optimizer behavior
- global instruction install still works
- project templates still install
- the Claude `SessionStart` hook still wires the seeding script
- the seeding script still injects missing project-local instruction files
- uninstall only removes the retained artifacts
- tests cover the retained behavior and no longer rely on removed subsystems

