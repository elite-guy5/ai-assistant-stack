# Project CLAUDE.md

> Project-specific Claude Code instructions. Inherits global behavior from `~/.claude/CLAUDE.md`.

Claude Code reads this file as persistent project context. Use
`.claude/settings.json`, `.claude/settings.local.json`, `.mcp.json`, and hooks
for technical enforcement.

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

### Coding Style and Architecture

> `<Project-specific coding patterns, import rules, architecture, directory layout, and design conventions>`

### Claude Code Settings and Hooks

> `<Project-specific Claude Code settings, hook files, permission boundaries, MCP servers, and local-only setup notes>`

### Model Routing & Token Enforcement (Claude/Anthropic Optimized)

- **Spec Writers & Architecture Reviewers:**
  - **Model:** `Opus` (or `Fable` for long-running architectural tasks)
  - **Effort Tier:** `High` / `Ultracode` (only for initial phase)
  - *Use Case:* High-level context synthesis, structural planning, and initial `SPEC.md` alignment.
- **Implementers & TDD Repair Loops:**
  - **Model:** `Sonnet 5` (or `Haiku 4.5` for raw speed)
  - **Effort Tier:** `Low` / `Medium`
  - *Use Case:* Writing basic unit tests, handling terminal commands, and execution loops. Dropping from Opus ($5/$25) to Haiku 4.5 ($1/$5) cuts your loop spend by 80% instantly.
- **Max Iteration Loop Limit:** Subagents are capped at a maximum of **3 regression/repair loops** per task. If a test fails 3 times sequentially, the agent **MUST halt**, save an error state, and hand execution back to the human.
- **Tool-Call Hard Cap:** Hard-cap tool calls at a maximum of **12,000 input tokens** to prevent context blowout from massive files during deep workflows.

---

## Token-Saver File Boundaries

- Keep generated files, secrets, logs, coverage reports, dependency folders,
  local databases, and binary assets out of agent context by default.
- Maintain source-control exclusions through `.gitignore`.
- Maintain Claude Code context and permission boundaries through:
  - `.claude/settings.json`
  - `.claude/settings.local.json`
  - `CLAUDE.local.md`
  - `.mcp.json` when project-scoped MCP servers are shared

- If this repository also supports Codex, maintain Codex-specific exclusions
  through `.codexignore` and `AGENTS.md` without making Claude Code depend on
  Codex configuration.
- If this repository requires broader or narrower exclusions, update the local
  ignore and settings files instead of weakening global behavior.

---

## Development Workflow

This repository inherits the global Claude Code session requirements:

- Use LeanCTX for AST-aware workspace scoping and compressed context when
  available.
- Activate Caveman for conversational efficiency while keeping code, commands,
  paths, APIs, flags, and errors exact.
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

Claude Code instruction loading is additive rather than simple replacement.

Claude Code loads broad instructions before narrower instructions:

```text
Managed CLAUDE.md
        |
User ~/.claude/CLAUDE.md
        |
Project CLAUDE.md or .claude/CLAUDE.md
        |
Local CLAUDE.local.md
```

Settings precedence is separate:

```text
Managed settings
        |
Command-line arguments
        |
Local .claude/settings.local.json
        |
Project .claude/settings.json
        |
User ~/.claude/settings.json
```

Use `CLAUDE.md` for behavioral guidance. Use Claude Code settings and hooks for
enforceable restrictions.

Project-specific overrides should be placed under **Conventions** whenever
possible.

---

## Memory Management

### Durable Knowledge

- Generalizable learnings and correction logs should be written directly to the
  personal Obsidian vault using the Obsidian integration when available.
- Project-specific durable notes should go to the repository's documented
  Obsidian destination when one exists.
- Only the primary supervising agent is authorized to write or append to the
  Obsidian vault to prevent parallel write-collision locks.

### Claude Code Memory

- Use `CLAUDE.md` for durable project instructions that every session should
  read.
- Use `CLAUDE.local.md` for private local preferences.
- Use Claude Code auto memory for learned preferences and repeated corrections
  when enabled.
- Use `.claude/rules/` or skills for scoped procedures that would bloat this
  file.
