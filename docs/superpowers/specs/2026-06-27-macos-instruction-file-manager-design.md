# macOS Instruction-File Manager Design

## Goal

Reduce this repository to a macOS-only installer for Codex and Claude Code
instruction files plus Git hook automation for future repositories.

## Retained Behavior

- Install selected global instruction files:
  - Codex: `~/.codex/AGENTS.md`
  - Claude Code: `~/.claude/CLAUDE.md`
- Install selected project templates:
  - Codex: `~/.codex/AGENTS.project-template.md`
  - Claude Code: `~/.claude/CLAUDE.project-template.md`
- Install `~/.agents/scripts/seed-project-instructions.sh`.
- Install managed Git template hooks under `~/.agents/git-template/hooks/`.
- Set `git config --global init.templateDir ~/.agents/git-template`.
- Offer current-repo setup during interactive installs and support explicit
  current-repo setup through `--repo <path>`.
- Uninstall only installer-managed artifacts recorded in local install state.

## Removed Behavior

- Non-macOS platform support.
- Session-start settings for agent applications.
- Ignore-boundary optimization scripts.
- External tool, plugin, package-manager, skill, protocol-server, or CLI installation.
- Any automated setup beyond instruction files and Git hooks.

## Installer Model

Interactive installs ask which tool to configure: Codex, Claude Code, or both.
Non-interactive installs require `--tools codex`, `--tools claude`, or
`--tools both`.

Existing global files and templates are skipped by default. Overwrite flags
create backups before replacing files.

## Hook Model

Git template hooks seed future repositories created with `git init`. Existing
repositories are configured only when the user passes `--repo` or accepts the
interactive current-repo prompt.

The hooks run the shared seeding script. The seeding script detects the Git
root and creates only the selected project instruction files. It does not run
installers or configure external tools.
