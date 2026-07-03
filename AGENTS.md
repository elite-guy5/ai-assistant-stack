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
3. Run the repository scan requested by the task when scope changes affect
   removed setup surfaces.
4. Run `git diff --check`.
5. Report failures directly instead of claiming success.

### Required Verification Flow

After editing files:

```text
1. Run the relevant project-native check for the changed files.
2. Run shell syntax checks when scripts or tests changed.
3. Run the shell regression suite when installer, hook, or template behavior changed.
4. Review the diff.
5. Declare completion only after verification passes or clearly report failures.
```

For documentation-only edits, `git diff --check -- <changed-files>` is the
minimum required verification.

---

## Conventions

### Testing

- Tests live under `tests/*.sh` and run with Bash.
- Tests create temporary homes and repositories so installer behavior is checked
  without mutating the real machine.
- Cover installer safety, tool selection, Git template hook behavior,
  current-repo hook wrapping, seeding, uninstall, bootstrap checksum checks, and
  removed setup surfaces.

### Coding Style & Architecture

- Keep scripts POSIX/Bash-style and aligned with the existing shell patterns.
- Keep installer behavior in `scripts/install.sh`; keep project-file seeding in
  `scripts/seed-project-instructions.sh`; keep bootstrap download/checksum
  behavior in `scripts/bootstrap.sh`.
- Keep reusable instruction text in `templates/*.md` and avoid hardcoding
  duplicate instruction bodies in scripts.
- Maintain the split between global instruction templates and project template
  files for both Codex and Claude Code.
- Prefer explicit, idempotent managed-marker updates for Git hooks and generated
  instruction files.
- Avoid adding package-manager, plugin, protocol-server, or external CLI setup
  paths unless the repository scope is explicitly expanded.

### Coding Standards

- Keep the installer Bash-only and macOS-focused.
- Do not add package-manager, plugin, skill, protocol-server, or external CLI
  setup paths unless the task explicitly expands installer scope.
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
- This checkout is used to validate Codex-focused instruction and hook setup.
  Keep repo guidance centered on Codex unless the task explicitly targets
  Claude Code templates.
- LeanCTX tool-footprint setup for this environment uses
  `lean-ctx tools minimal`. Do not document `lean-ctx config set mode lazy`
  unless that command has been re-verified against the installed LeanCTX
  version.

---

## Token-Saver File Boundaries

Unless required for the current task, avoid loading generated artifacts,
dependency directories, logs, coverage reports, build outputs, secrets, binary
assets, and local databases.

Project-specific exclusions should be maintained through `.gitignore`,
`.codexignore`, `.claude/settings.json`, and related ignore files.

This repository maintains these context-boundary files:

- `.gitignore`
- `.codexignore`
- `.claude/settings.json`
- `.copilotignore`

If this repository requires broader or narrower exclusions, update the local
ignore files and verify them with `git check-ignore -v` when relevant.

---

## Development Workflow

This repository inherits the global session requirements:

- Use LeanCTX for AST-aware workspace scoping when available.
- Activate Caveman for conversational efficiency when available.
- Treat Superpowers as optional. Invoke it only when explicitly requested or
  when an active workflow already requires it.

When Superpowers is manually invoked, follow the active Superpowers skill
workflow, including its spec, plan, worktree, and verification requirements.

When Superpowers is not in use, follow this repository's normal development and
verification rules.

### 1. Planning And Subagents

Use subagents only when persistent task state, parallel investigation,
isolation, or review checkpoints materially help.

Do not spawn additional agents for docs-only edits, one-file fixes, simple
config changes, command output checks, formatting, linting, or tasks where all
steps must be performed sequentially.

Default flow:

```text
1. Clarify the goal or use the active Superpowers plan when one exists.
2. Split the work into atomic tasks with clear file ownership and verification.
3. Keep sequential or tightly coupled work in the main agent.
4. Use focused subagents only for independent tasks.
5. Use the main agent as supervisor and final reviewer.
```

### 2. Test-Driven Development

This repository prefers TDD by default for non-trivial code changes.

Follow the Red, Green, Refactor cycle when practical:

1. Write a failing test.
2. Verify the test fails with the project-native test command.
3. Implement the minimum code required.
4. Refactor while keeping tests green.

For trivial changes, documentation-only edits, or config-only changes, use the
most relevant verification command instead.

### 3. Code Review And Branch Completion

Workflow:

```text
Request code review
        |
Address feedback
        |
Run verification
        |
Merge or create PR
        |
Clean up branch
```

- Review `git diff` before reporting completion.
- Mention unrelated dirty files separately; do not revert or normalize them
  unless explicitly asked.

---

## Instruction Precedence

Instruction precedence is:

```text
Direct user request
        |
Local project AGENTS.md
        |
Global ~/.codex/AGENTS.md
        |
Applicable skills and tool instructions
```

Project-specific overrides should be placed under **Conventions** or
**Development Workflow** whenever possible.

---

## Memory Management

### Durable Knowledge

- Generalizable learnings and correction logs should be written directly to the
  personal Obsidian vault using the Obsidian integration when available.
- Project-specific durable notes for this repository belong under
  `Projects/Token Saver Setup` in the Obsidian vault.
- Only the primary supervising agent is authorized to write or append to the
  Obsidian vault to prevent parallel write-collision locks.
