# Project AGENTS.md

> Project-specific instructions. Inherits global behavior from `~/.codex/AGENTS.md`.

## Project Info

**Purpose**

> `<One-line description of the project's core utility, service, or business objective>`

**Language / Framework**

> `<Primary languages, frameworks, runtime environments, and database engines>`

**Key Entry Points**

> `<Comma-separated list of critical source files, entry components, configuration files, or routing manifests>`

---

## Commands

| Task | Command |
|------|---------|
| **Build** | `<Build command>` |
| **Test** | `<Command to execute unit, integration, or smoke tests>` |
| **Lint** | `<Command to lint, format, or typecheck files, or note if handled globally>` |
| **Run** | `<Command to launch the application locally, including expected host and port>` |

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

> `<Testing conventions: test locations, frameworks, coverage expectations, and naming conventions>`

### Coding Style & Architecture

> `<Project-specific coding patterns, import rules, architecture, directory layout, and design conventions>`

---

## Token-Saver File Boundaries

- Keep generated files, secrets, logs, coverage reports, dependency folders, local databases, and binary assets out of agent context by default.
- Project seeding maintains:
  - `.gitignore`
  - `.codexignore`
  - `.claude/settings.local.json`

  with common token-bloat exclusions.
- If this repository requires broader or narrower exclusions, update the local ignore files instead of weakening the global behavior.

---

# Development Workflow

This repository inherits the global session requirements:

- Automatically load LeanCTX for AST-aware workspace scoping.
- Automatically enable the Ruflo harness for daemon workers and trajectory learning.
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

Follow the Red → Green → Refactor cycle:

1. Write a failing test.
2. Verify the test fails.
3. Implement the minimum code required.
4. Refactor while keeping tests green.

---

### 6. Code Review & Branch Completion

Workflow:

```text
Request Code Review
        ↓
Address Feedback
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

## Memory Management

### Durable Knowledge

Generalizable learnings and correction logs should be written directly to the personal Obsidian vault using the Obsidian MCP integration.

### Execution Memory

Persistent execution history, trajectory learning, and long-term operational memory are managed automatically by Ruflo through its AgentDB vector storage layers.