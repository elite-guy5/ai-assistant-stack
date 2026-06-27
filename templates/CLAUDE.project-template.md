# Project AGENTS.md

> Project-specific instructions. Inherits global behavior from `~/.claude/CLAUDE.md`.

## Project Info

### Purpose

> `<One-line description of the project's core utility, service, or business objective>`

### Language / Framework

> `<Primary languages, frameworks, runtime environments, and database engines>`

### Key Entry Points

> `<Comma-separated list of critical source files, entry components, configuration files, or routing manifests>`

---

## Commands

| Task | Command |
|------|---------|
| **Build** | `<Build command>` |
| **Test** | `<Command to execute unit, integration, or smoke tests>` |
| **Format** | `<Project-native formatter command, such as npm run format, pnpm format, prettier --write <file>, ruff format <file>, cargo fmt, or gofmt -w <file>>` |
| **Lint / Typecheck** | `<Project-native lint, format-check, or typecheck command>` |
| **Run** | `<Command to launch the application locally, including expected host and port>` |

### Verification Hooks

Do **not** assume Ruflo provides formatter or linter commands.

Ruflo v3.14.2 does not expose `format` or `lint` as CLI commands, so agents must **not** call:

```bash
ruflo format <file>
ruflo lint
```

Instead:

- Use the project-native formatter after edits.
- Use the project-native lint/typecheck/test commands before declaring work complete.
- Use Ruflo only for supported harness, hook, memory, MCP, swarm, or orchestration commands confirmed by:

```bash
ruflo --help
```

### Required Verification Flow

After editing files:

```text
1. Run the project-native formatter for changed files.
2. Run the project-native lint/typecheck command.
3. Run the relevant tests.
4. Review the diff.
5. Declare completion only after verification passes or clearly report failures.
```

If the project has no formatter, linter, or tests yet, state that explicitly and verify with the best available command.

---

## Conventions

### Testing

> `<Testing conventions: test locations, frameworks, coverage expectations, and naming conventions>`

### Coding Style & Architecture

> `<Project-specific coding patterns, import rules, architecture, directory layout, and design conventions>`

---

## Token-Saver File Boundaries

- Keep generated files, secrets, logs, coverage reports, dependency folders, local databases, and binary assets out of agent context by default.
- Project seeding maintains:
  - `.gitignore`
  - `.claudeignore`
  - `.claude/settings.local.json`

- If this repository requires broader or narrower exclusions, update the local ignore files instead of weakening global behavior.

---

# Development Workflow

This repository inherits the global session requirements:

- Automatically load LeanCTX for AST-aware workspace scoping.
- Automatically enable the Ruflo harness for daemon workers and trajectory learning.
- Automatically activate the Caveman skill for conversational efficiency.

When software development work is requested, follow the Superpowers workflow where relevant.

## Standard Workflow

### 1. Brainstorming

- Refine the idea.
- Obtain design approval when the requested change is ambiguous, broad, or architectural.
- Save design specifications using the current system date to:

```text
docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md
```

---

### 2. Writing Plans

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

### 6. Code Review & Branch Completion

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
Global ~/.claude/AGENTS.md
```

Project-specific overrides should be placed under the **Conventions** section whenever possible.

---

## Memory Management

### Durable Knowledge

- Generalizable learnings and correction logs should be written directly to the personal Obsidian vault using the Obsidian MCP integration when available.
- **Collision Prevention:** Only the primary supervising agent is authorized to write or append to the Obsidian vault via MCP tools to prevent parallel write-collision locks. Subagents must never call Obsidian tools.

### Execution Memory

- Persistent execution history, trajectory learning, and long-term operational memory are managed by Ruflo through its AgentDB vector storage layers when available. Subagents will exclusively log their operational discoveries and context here.