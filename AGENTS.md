# Project AGENTS.md

> Project-specific instructions. Inherits global behavior from `~/.codex/AGENTS.md`.

## Project Info

**Purpose**

Installer and project seeding toolkit for token-efficient AI agent environments.
It installs global Claude/Codex instructions, project instruction templates,
Claude `SessionStart` seeding hooks, RTK/Caveman integration helpers, and
AI ignore boundaries.

**Language / Framework**

Bash, PowerShell, JSON configuration files, Markdown instruction templates, and
shell-based regression tests. Node is used by installer scripts for safe JSON
manifest and Claude settings edits.

**Key Entry Points**

`scripts/install.sh`, `scripts/install.ps1`, `scripts/bootstrap.sh`,
`scripts/bootstrap.ps1`, `scripts/seed-project-instructions.sh`,
`scripts/seed-project-instructions.ps1`, `scripts/optimize-ai.sh`,
`scripts/optimize-ai.ps1`, `templates/AGENTS.global.md`,
`templates/AGENTS.project-template.md`, `templates/CLAUDE.global.md`,
`templates/CLAUDE.project-template.md`, `config/claude-settings-sessionstart.json`,
`config/claude-settings-sessionstart.windows.json`, `tests/*.sh`.

---

## Commands

| Task | Command |
|------|---------|
| **Build** | No compiled build. Validate syntax with `bash -n scripts/*.sh tests/*.sh`; if PowerShell is available, parse `scripts/*.ps1`. |
| **Test** | `for test in tests/*.sh; do bash "$test"; done` |
| **Lint** | `ruflo lint` before completion; use `bash -n scripts/*.sh tests/*.sh` for shell syntax. |
| **Run** | `bash scripts/install.sh --dry-run --non-interactive` for a safe local preview. |

### Global Verification Hooks

Always run:

```bash
ruflo format <file>
```

after editing files, and:

```bash
ruflo lint
```

before declaring a task complete.

---

## Conventions

### Testing

- Tests live under `tests/*.sh`.
- Tests create temporary homes and stub external CLIs so installer behavior can
  be checked without mutating the real machine.
- PowerShell cases are conditional and should skip gracefully when `pwsh` is not
  installed.
- `expect`-based prompt tests are conditional where appropriate, except tests
  that explicitly require `expect`.
- Security tests must keep checksum verification, symlink refusal, user-owned
  file preservation, and unverified-download protections covered.

### Coding Style & Architecture

- Keep Bash and PowerShell installer behavior in parity.
- Preserve user-owned files by default. Overwrite only through explicit
  overwrite flags.
- Keep bootstrap scripts thin: download the pinned archive, verify checksum, and
  dispatch to the local installer.
- Edit Claude settings and install manifests through structured JSON tooling,
  not string replacement.
- Keep `scripts/seed-project-instructions.*` bounded to the configured project
  scope before writing project-local instruction files.
- Keep `scripts/optimize-ai.*` focused on generated-file, secret, dependency,
  coverage, log, database, and binary-asset exclusions.
- Do not add dependencies unless the installer or tests cannot meet the safety
  contract without them.

---

## Token-Saver File Boundaries

- Keep generated files, secrets, logs, coverage reports, dependency folders,
  local databases, and binary assets out of agent context by default.
- Project seeding and optimization currently maintain:
  - `.gitignore`
  - `.codexignore`
  - `.claude/settings.local.json`

  with common token-bloat exclusions.
- If this repository requires broader or narrower exclusions, update the local
  ignore files instead of weakening the global behavior.

---

# Development Workflow

This repository inherits the global session requirements:

- Automatically load LeanCTX for AST-aware workspace scoping.
- Automatically enable the Ruflo harness for daemon workers and trajectory
  learning.
- Automatically activate the Caveman skill for conversational efficiency.

When software development work is requested, follow the Superpowers workflow.

## Standard Workflow

### 1. Brainstorming

- Refine the idea.
- Obtain design approval.
- Save the design specification to:

```text
docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md
```

---

### 2. Writing Plans

- Break work into small, verifiable tasks.
- Include exact file paths.
- Define required tests.

Save the implementation plan to:

```text
docs/superpowers/plans/YYYY-MM-DD-<feature>.md
```

---

### 3. Using Git Worktrees

- Create an isolated worktree.
- Begin from a clean test baseline.

---

### 4. Subagent-Driven Development / Executing Plans

- Execute tasks sequentially.
- Use review checkpoints.
- Delegate independent work to subagents where appropriate.

---

### 5. Test-Driven Development (Required)

This repository enforces TDD by default.

Follow the Red -> Green -> Refactor cycle:

1. Write a failing test.
2. Verify the test fails.
3. Implement the minimum code required.
4. Refactor while keeping tests green.

---

### 6. Code Review & Branch Completion

Workflow:

```text
Request Code Review
        |
Address Feedback
        |
Merge / Create PR
        |
Cleanup Branches
```

---

## Instruction Precedence

Instruction precedence is:

```text
Local AGENTS.md
        |
Superpowers Skills
        |
Global ~/.codex/AGENTS.md
```

Project-specific overrides should be placed under the **Conventions** section
whenever possible.

---

## Memory Management

### Durable Knowledge

Generalizable learnings and correction logs should be written directly to the
personal Obsidian vault using the Obsidian MCP integration.

### Execution Memory

Persistent execution history, trajectory learning, and long-term operational
memory are managed automatically by Ruflo through its AgentDB vector storage
layers.
