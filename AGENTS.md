# Project AGENTS.md

> Project-specific instructions. Inherits global behavior from `~/.codex/AGENTS.md`.

## Project Info

### Purpose

AI Assistant Stack is a Bash-based installer and bootstrapper for configuring token-efficient AI coding environments across Codex and Claude Code.

It installs and manages global instruction files, project templates, repository seeding hooks, and optional stack tooling for LeanCTX, Context7, Caveman, and Superpowers.

### Language / Framework

- Primary language: Bash shell scripts.
- Documentation and templates: Markdown.
- Runtime environment: macOS-oriented POSIX shell environment with Git; `scripts/bootstrap.sh` also requires `curl` or `wget` for remote archive installs.
- External tools configured or invoked: `lean-ctx`, `codex`, `claude`, `code`, `npx`, Git hooks, and Context7 MCP setup commands.
- No application framework, package manager manifest, compiled build, or database layer is configured in this repository.

### Key Entry Points

- `README.md`: user-facing install, uninstall, bootstrap, and development guide.
- `scripts/bootstrap.sh`: clone-free remote bootstrap entry point.
- `scripts/install.sh`: main installer, uninstall flow, dry-run behavior, and hook installation logic.
- `scripts/lib/targets.sh`: target selection and `--targets` to `--tools` derivation.
- `scripts/lib/preflight.sh`: selected-target prerequisite checks.
- `scripts/lib/stack-tools.sh`: LeanCTX, Context7, Caveman, and Superpowers setup.
- `scripts/lib/logging.sh`: install logging and redaction helpers.
- `scripts/seed-project-instructions.sh`: project instruction file seeding logic.
- `templates/AGENTS.global.md`, `templates/AGENTS.project-template.md`, `templates/CLAUDE.global.md`, `templates/CLAUDE.project-template.md`: installed instruction templates.
- `docs/codex-agent-stack-setup.md`, `docs/claude-agent-stack-setup.md`: stack setup references used by the README and installer behavior.
- `tests/*.sh`: shell regression suite for installer behavior, targets, preflight, logging, hooks, bootstrap, and security-sensitive flows.
- `.gitignore`, `.codexignore`, `.copilotignore`, `.claude/settings.json`: local context and secret-boundary configuration.

---

## Commands

| Task | Command |
|------|---------|
| **Build** | No compiled build is configured. Use `bash -n scripts/*.sh tests/*.sh` as the syntax/build-equivalent check. |
| **Test** | `for test in tests/*.sh; do bash "$test"; done` |
| **Format** | No project-native formatter is configured. Preserve the existing Bash and Markdown style. |
| **Lint / Typecheck** | `bash -n scripts/*.sh tests/*.sh` |
| **Run** | No local server is provided. Use `bash scripts/install.sh --dry-run --non-interactive --tools both` for a local installer preview, or `bash scripts/bootstrap.sh --dry-run --non-interactive --tools both` for bootstrap-path verification. |

### Required Verification Flow

After editing files:

```text
1. Run the project-native formatter for changed files, if configured.
2. Run the project-native lint or typecheck command, if configured.
3. Run the relevant tests.
4. Review the diff.
5. Declare completion only after verification passes or clearly report failures.
```

If the project has no formatter, linter, or tests yet, state that explicitly and
verify with the best available command.

---

## Conventions

### Testing

- Tests live in `tests/*.sh` and are plain Bash scripts with `set -euo pipefail`.
- Each test script creates temporary homes, repositories, archives, or stub executables as needed so installer behavior can be verified without mutating the real user environment.
- Run one focused test with `bash tests/<name>.sh`.
- Run the full regression suite with `for test in tests/*.sh; do bash "$test"; done`.
- Run `bash -n scripts/*.sh tests/*.sh` before or with behavior tests after editing shell files.
- High-value regression coverage includes:
  - `tests/install-dry-run.sh` for non-interactive and dry-run behavior.
  - `tests/install-targets.sh` for target normalization and tool derivation.
  - `tests/install-preflight.sh` for fail-fast prerequisite checks.
  - `tests/install-stack-tools.sh` for stack setup command paths.
  - `tests/security-regression.sh` for managed hook behavior, archive checksum handling, clone-free bootstrap, and piped-bootstrap execution.

### Coding Style & Architecture

- Keep installer logic in Bash and match the existing `set -euo pipefail` style.
- Keep shared helper logic in `scripts/lib/*.sh`; source helpers from `scripts/install.sh` rather than duplicating target, preflight, logging, or stack-tool logic.
- Keep `scripts/bootstrap.sh` limited to archive download, optional checksum verification, archive extraction, prompt TTY handling, and dispatch to `scripts/install.sh`.
- Keep instruction-file seeding behavior in `scripts/seed-project-instructions.sh`; it should skip existing project instruction files unless overwrite is explicit.
- Preserve dry-run behavior by routing filesystem and external commands through the existing `run` / `run_logged` helpers where practical.
- Preserve secret redaction for Context7 credentials and do not print raw API keys in logs, dry-run output, tests, or docs.
- Managed Git hook content should keep `TOKEN_SAVER_MANAGED_HOOK_BEGIN` / `TOKEN_SAVER_MANAGED_HOOK_END` markers so reruns and uninstall remain deterministic.
- Prefer explicit shell assertions inside tests over adding a test framework or package-managed dependency.
- Keep the repository package-free unless a requested change truly requires a dependency manager.
- Treat docs and templates as part of the product surface; changes to `README.md`, `docs/*.md`, and `templates/*.md` should stay consistent with actual installer flags and behavior.

---

## Token-Saver File Boundaries

- Keep generated files, secrets, logs, coverage reports, dependency folders,
  local databases, and binary assets out of agent context by default.
- Projects should maintain:
  - `.gitignore`
  - `.codexignore`
  - `.claude/settings.json`

- If this repository requires broader or narrower exclusions, update the local
  ignore files instead of weakening global behavior.
- Keep `.claude/settings.local.json` for private machine-local Claude settings
  only, and do not commit it.

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

---

## Instruction Precedence

Instruction precedence is:

```text
Local AGENTS.md
        |
Applicable skills, including Superpowers when invoked
        |
Global ~/.codex/AGENTS.md
```

Project-specific overrides should be placed under the **Conventions** section
whenever possible.

---

## Memory Management

### Durable Knowledge

- Generalizable learnings and correction logs should be written directly to the
  personal Obsidian vault using the Obsidian integration when available.
- Only the primary supervising agent is authorized to write or append to the
  Obsidian vault to prevent parallel write-collision locks.
