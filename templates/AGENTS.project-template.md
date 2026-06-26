# Project AGENTS.md

> Project-specific instructions. Inherits global behavior from `~/.codex/AGENTS.md`.

## Project Info

### Purpose

Use this section only for details that affect how agents should work in this repository.

General project description, setup, and user-facing documentation belong in `README.md`.

> `<One-line description of the project's core utility, service, or business objective>`

### Language / Framework

> `<Primary languages, frameworks, runtime environments, and database engines>`

### Key Entry Points

> `<Comma-separated list of critical source files, entry components, configuration files, or routing manifests>`

---

## Development Commands

| Task | Command |
|------|---------|
| **Build** | `<Build command>` |
| **Test** | `<Command to execute unit, integration, or smoke tests>` |
| **Format** | `<Project-native formatter command, such as npm run format, pnpm format, prettier --write <file>, ruff format <file>, cargo fmt, or gofmt -w <file>>` |
| **Lint / Typecheck** | `<Project-native lint, format-check, or typecheck command>` |
| **Run** | `<Command to launch the application locally, including expected host and port>` |

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

> `<Testing conventions: test locations, frameworks, coverage expectations, and naming conventions>`

### Coding Standards

> `<Project-specific coding patterns, import rules, architecture, directory layout, and design conventions>`

### Project-Specific Rules

> `<Business rules, coding preferences, workflow requirements, or repository-specific guidance>`

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

If this repository uses additional tools (Ruflo, Superpowers, LeanCTX, MCP servers, etc.), document only project-specific behavior here.

Global tool configuration belongs in the global `AGENTS.md`.

Avoid duplicating global instructions unless the project intentionally overrides them.

---

## Memory Management

### Durable Knowledge

- Generalizable learnings and correction logs should be written directly to the personal Obsidian vault using the Obsidian MCP integration when available.
- **Collision Prevention:** Only the primary supervising agent is authorized to write or append to the Obsidian vault via MCP tools to prevent parallel write-collision locks. Subagents must never call Obsidian tools.

### Execution Memory

- Persistent execution history, trajectory learning, and long-term operational memory are managed by Ruflo through its AgentDB vector storage layers when available. Subagents will exclusively log their operational discoveries and context here.