# Project AGENTS.md

> Project-specific instructions. Inherits global behavior from `~/.codex/AGENTS.md`.

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

> `<Testing conventions: test locations, frameworks, coverage expectations, and naming conventions>`

### Coding Style & Architecture

> `<Project-specific coding patterns, import rules, architecture, directory layout, and design conventions>`

### 🤖 Model Routing & Token Enforcement

- **Spec Writers & Architecture Reviewers:**
  - **Model:** `GPT-5.5`
  - **Reasoning Tier:** `High` (or `Medium`)
  - *Use Case:* High-level context synthesis and architectural guardrails.
- **Implementers & TDD Repair Loops:**
  - **Model:** `GPT-5.4-Mini` OR route strictly to the `Speed` profile.
  - **Reasoning Tier:** `Light`
  - *Use Case:* Writing basic unit tests and localized file modifications. This stops execution loops from burning premium limits.
- **Max Iteration Loop Limit:** Subagents are capped at a maximum of **3 regression/repair loops** per task. If a test fails 3 times sequentially, the agent **MUST halt**, save an error state, and hand execution back to the human.
- **Tool-Call Hard Cap:** Hard-cap tool calls at a maximum of **12,000 input tokens** to prevent context blowout from massive files.
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

### Context & Active Knowledge
- State tracking, temporal facts, and session discoveries are managed natively by LeanCTX via `ctx_knowledge`.
- Do not attempt to automatically write correction logs, session journals, or lessons learned to an external Obsidian vault or personal notes.
- If high-leverage architectural changes or unique domain patterns are established, focus entirely on the engineering execution loop. 
- Provide a clean, markdown-formatted technical summary of the session *only* if explicitly requested by the human for manual curation.
