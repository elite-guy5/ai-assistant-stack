# Project AGENTS.md

> Project-specific instructions. Inherits global behavior from `~/.codex/AGENTS.md`.

## Project Info

### Purpose

macOS-only installer for Codex and Claude Code instruction files plus Git hook
automation that seeds project-level instruction files into Git repositories.

### Language / Framework

Bash, Markdown instruction templates, Git hook scripts, and shell-based
regression tests.

### Key Entry Points

`scripts/install.sh`, `scripts/bootstrap.sh`,
`scripts/seed-project-instructions.sh`, `templates/AGENTS.global.md`,
`templates/AGENTS.project-template.md`, `templates/CLAUDE.global.md`,
`templates/CLAUDE.project-template.md`, and `tests/*.sh`.

---

## Development Commands

| Task | Command |
|------|---------|
| **Build** | No compiled build; scripts are interpreted. |
| **Test** | `for test in tests/*.sh; do bash "$test"; done` |
| **Format** | No project-native formatter is configured. Preserve existing shell and Markdown style. |
| **Lint / Typecheck** | `bash -n scripts/*.sh tests/*.sh` |
| **Run** | `bash scripts/install.sh --dry-run --non-interactive --tools both` |

## Verification Requirements

After code changes:

1. Run `bash -n scripts/*.sh tests/*.sh`.
2. Run `for test in tests/*.sh; do bash "$test"; done`.
3. Run the repository scan requested by the task when scope changes affect removed setup surfaces.
4. Run `git diff --check`.
5. Report failures directly instead of claiming success.

---

## Conventions

### Testing

- Tests live under `tests/*.sh` and run with Bash.
- Tests create temporary homes and repositories so installer behavior is checked
  without mutating the real machine.
- Cover installer safety, tool selection, Git template hook behavior,
  current-repo hook wrapping, seeding, uninstall, and bootstrap checksum checks.

### Coding Standards

- Keep the installer Bash-only and macOS-focused.
- Do not add package-manager, plugin, skill, protocol-server, or external CLI setup paths.
- Preserve user-owned files by default. Overwrite only when an explicit
  overwrite flag is provided, and create backups before replacement.
- Keep hooks idempotent by using managed markers.
- Keep hooks limited to `AGENTS.md` and `CLAUDE.md` project instruction files.
- Do not delete repo-local instruction files during uninstall.

### Project-Specific Rules

- Interactive install asks whether to configure Codex, Claude Code, or both.
- Non-interactive install requires `--tools codex`, `--tools claude`, or
  `--tools both`.
- Future repository support is provided through Git template hooks under
  `~/.agents/git-template/hooks/`.
- Existing repositories are configured only when the user passes `--repo` or
  accepts the interactive current-repo prompt.

---

## Context Boundaries

Unless required for the current task, avoid loading generated artifacts,
dependency directories, logs, coverage reports, build outputs, secrets, binary
assets, and local databases.

Project-specific exclusions should be maintained through `.gitignore`,
`.codexignore`, `.claude/settings.local.json`, and related ignore files.

---

## Memory Management

### Durable Knowledge

- Generalizable learnings and correction logs should be written directly to the
  personal Obsidian vault using the Obsidian integration when available.
- Project-specific durable notes for this repository belong under
  `Projects/Token Saver Setup` in the Obsidian vault.
- Only the primary supervising agent is authorized to write or append to the
  Obsidian vault to prevent parallel write-collision locks.
