# Project AGENTS.md

> Project-specific instructions. Inherits global behavior from `~/.codex/AGENTS.md`.

## Project Info

### Purpose

Use this section only for details that affect how agents should work in this repository.

General project description, setup, and user-facing documentation belong in `README.md`.

Installer and project seeding toolkit for token-efficient AI agent workspaces.

### Language / Framework

Bash, PowerShell, Markdown instruction templates, JSON configuration files, and shell-based regression tests. Node is used by installer scripts for structured JSON edits to Claude settings and install manifests.

### Key Entry Points

`scripts/install.sh`, `scripts/install.ps1`, `scripts/bootstrap.sh`, `scripts/bootstrap.ps1`, `scripts/seed-project-instructions.sh`, `scripts/seed-project-instructions.ps1`, `scripts/optimize-ai.sh`, `scripts/optimize-ai.ps1`, `templates/AGENTS.global.md`, `templates/AGENTS.project-template.md`, `templates/CLAUDE.global.md`, `templates/CLAUDE.project-template.md`, `config/claude-settings-sessionstart.json`, `config/claude-settings-sessionstart.windows.json`, `tests/*.sh`.

---

## Development Commands

| Task | Command |
|------|---------|
| **Build** | No compiled build; scripts are interpreted. Use lint/typecheck and tests as the build gate. |
| **Test** | `for test in tests/*.sh; do bash "$test"; done` |
| **Format** | No project-native formatter is configured. Preserve existing shell/PowerShell style and report that no formatter exists. |
| **Lint / Typecheck** | `bash -n scripts/*.sh tests/*.sh` plus the PowerShell parser check below when `pwsh` is available. |
| **Run** | `bash scripts/install.sh --dry-run --non-interactive` for a safe local preview; this repo has no long-running local server or port. |

## Verification Requirements

Agents must never assume orchestration tools expose project build, formatting, linting, or testing commands.

Always use the project's native development commands.

After making code changes:

1. Format modified files.
2. Run linting and/or type checking.
3. Run relevant tests.
4. Review the diff.
5. Report any failures instead of claiming success.

If the project has no formatter, linter, or tests, state that explicitly and use the best available verification.

---

## Conventions

### Testing

- Tests live under `tests/*.sh` and run with Bash.
- Use `for test in tests/*.sh; do bash "$test"; done` for the full shell regression suite.
- Common focused checks include `tests/install-dry-run.sh`, `tests/security-regression.sh`, `tests/install-visible-output.sh`, `tests/install-uninstall-prompt.sh`, `tests/ai-ignore-smoke.sh`, and `tests/rtk-claude-hook.sh`.
- Tests create temporary homes and stub external CLIs so installer behavior can be checked without mutating the real machine.
- PowerShell cases are conditional and should skip gracefully when `pwsh` is not installed.
- Prompt tests use `expect` where needed; keep those checks conditional unless the test explicitly requires `expect`.
- Security tests must preserve coverage for checksum verification, symlink refusal, user-owned file preservation, and unverified-download protections.

### Coding Standards

- Keep Bash and PowerShell installer behavior in parity.
- Preserve user-owned files by default. Overwrite only through explicit overwrite flags.
- Keep bootstrap scripts thin: download the pinned archive, verify checksum, and dispatch to the local installer.
- Edit Claude settings and install manifests through structured JSON tooling, not string replacement.
- Keep `scripts/seed-project-instructions.*` bounded to the configured project scope before writing project-local instruction files.
- Keep `scripts/optimize-ai.*` focused on generated-file, secret, dependency, coverage, log, database, and binary-asset exclusions.
- Do not add dependencies unless the installer or tests cannot meet the safety contract without them.

### Project-Specific Rules

- Retained installer scope is global instruction installation, project template installation, project seeding scripts that create missing `CLAUDE.md` and `AGENTS.md` files from templates, Claude `SessionStart` hook wiring, AI ignore-boundary maintenance, and uninstall behavior for installer-managed artifacts.
- Existing global instructions and project templates are skipped by default unless an overwrite flag is provided.
- Use `~/.agents/install_manifest.json` to distinguish installer-created artifacts from user-owned files during uninstall behavior.
- Keep local token boundaries additive. Do not weaken existing ignore, permission, or instruction rules.

---

## Context Boundaries

Unless required for the current task, avoid loading:

- generated artifacts
- dependency directories
- logs
- coverage reports
- build outputs
- secrets
- binary assets
- local databases

Project-specific exclusions should be maintained through:

- `.gitignore`
- `.codexignore`
- `.claude/settings.local.json`
- other repository ignore files as appropriate

---

# Development Workflow

This repository inherits the global workflow defined in `~/.codex/AGENTS.md`.

Use the following project workflow when applicable.

## Standard Workflow

### 1. Design

- Refine the idea.
- Obtain design approval when the requested change is ambiguous, broad, or architectural.
- Save design specifications using the current system date to:

```text
docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md
```

---

### 2. Planning

- Break work into small, verifiable tasks.
- Include exact file paths.
- Define required tests and verification commands.
- Use project-native formatter, lint, and test commands.
- Save implementation plans using the current system date to:

```text
docs/superpowers/plans/YYYY-MM-DD-<feature>.md
```

---

### 3. Using Git Worktrees

- Create an isolated worktree when appropriate.
- Begin from a clean test baseline.
- Do not create worktrees for trivial one-file fixes unless requested.

---

### 4. Multi-Agent Orchestration (Optional)

- Feed the generated implementation plan files directly into the `ruflo-swarm` engine for execution.
- **Execution Topology:** Allow Ruflo to execute independent, parallel subagents across the workspace using isolated git worktrees. Highly dependent tasks or sequential logic changes must be processed linearly.
- Use review checkpoints at the end of major milestones.
- Keep each subagent tightly focused on one atomic task.

#### Model Routing

Default to the least expensive model capable of completing the task accurately.

| Role | Recommended Model |
|------|-------------------|
| Planner / Supervisor | Strongest reasoning model |
| Implementation | Mid-tier model |
| Testing / Verification | Mid-tier model |
| Documentation | Lightweight model |
| Final Review | Strongest reasoning model |

Escalate to the strongest reasoning model when:

- requirements are ambiguous
- architectural decisions are required
- security, authentication, or data integrity is affected
- changes span multiple subsystems
- repeated verification failures occur
- performing the final code review

Avoid spawning additional agents for:

- documentation-only work
- formatting or linting
- simple configuration changes
- trivial single-file edits

---

### 5. Test-Driven Development

This repository prefers TDD by default for non-trivial code changes.

Follow the Red → Green → Refactor cycle when practical:

1. Write a failing test.
2. Verify the test fails inside Ruflo's sandbox harness. If a subagent encounters sequential test loop failures, route the telemetry directly into Superpowers' `systematic-debugging` engine.
3. Implement the minimum code required.
4. Refactor while keeping tests green.

For trivial changes, documentation-only edits, or config-only changes, use the most relevant verification command instead.

---

### 6. Code Review

Workflow:

```text
Request Code Review
        ↓
Address Feedback
        ↓
Run Verification
        ↓
Merge / Create PR
        ↓
Cleanup Branches
```

---

## Instruction Precedence

Instruction precedence is:

```text
Local AGENTS.md
        ↓
Superpowers Skills
        ↓
Global ~/.codex/AGENTS.md
```

Project-specific overrides should be placed under the **Conventions** section whenever possible.

---

## Tooling Notes

Agents must never assume orchestration tools expose project build, formatting, linting, or testing commands. Use the native commands above.

Ruflo v3.14.2 does not expose `format` or `lint` CLI commands, so do not run `ruflo format <file>` or `ruflo lint`. Use Ruflo only for supported harness, hook, memory, MCP, swarm, or orchestration commands confirmed by `ruflo --help`.

PowerShell parser check:

```powershell
pwsh -NoProfile -Command '$errors = $null; foreach ($file in Get-ChildItem scripts/*.ps1) { $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors); if ($errors.Count) { $errors; exit 1 } }'
```

Global tool configuration belongs in the global `AGENTS.md`; keep this file focused on project-specific behavior.

---

## Memory Management

### Durable Knowledge

- Generalizable learnings and correction logs should be written directly to the personal Obsidian vault using the Obsidian MCP integration when available.
- **Collision Prevention:** Only the primary supervising agent is authorized to write or append to the Obsidian vault via MCP tools to prevent parallel write-collision locks. Subagents must never call Obsidian tools.

### Execution Memory

- Persistent execution history, trajectory learning, and long-term operational memory are managed by Ruflo through its AgentDB vector storage layers when available. Subagents will exclusively log their operational discoveries and context here.
