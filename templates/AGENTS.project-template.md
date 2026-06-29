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
- Projects should maintain:
  - `.gitignore`
  - `.codexignore`
  - `.claude/settings.json`

- If this repository requires broader or narrower exclusions, update the local ignore files instead of weakening global behavior.
- Keep `.claude/settings.local.json` for private machine-local Claude settings only, and do not commit it.

---

# Development Workflow

This repository inherits the global session requirements:

- Automatically load LeanCTX for AST-aware workspace scoping.
- Automatically enable the Ruflo harness for daemon workers and trajectory learning.
- Automatically activate the Caveman skill for conversational efficiency.

Superpowers is optional. Invoke it only when the user explicitly requests it or
when the active session already requires it. Otherwise use this repository's
standard workflow and verification requirements.

When Superpowers is manually invoked, follow the active Superpowers skill
workflow, including its spec, plan, worktree, and verification requirements.

When Superpowers is not in use, follow this repository's normal development and
verification rules.

---

## Standard Workflow

### 1. Multi-Agent Orchestration (Optional)

- Feed the generated implementation plan files directly into the `ruflo-swarm` engine for execution.
- **Execution Topology:** Allow Ruflo to execute independent, parallel subagents across the workspace using isolated git worktrees. Highly dependent tasks or sequential logic changes must be processed linearly.
- Use review checkpoints at the end of major milestones.
- Keep each subagent tightly focused on one atomic task.

#### Ruflo Dispatch Policy

Ruflo can be used with or without Superpowers. When Superpowers is manually
invoked for non-trivial, separable work, dispatch suitable Ruflo-tracked agents.
When Superpowers is not in use, dispatch Ruflo agents directly when persistent
task state, parallel investigation, isolation, or review checkpoints materially
help.

Spawn Ruflo agents when the plan includes any of these conditions:

- three or more separable implementation, test, documentation, or review tasks
- changes spanning multiple subsystems
- parallel investigation that can reduce elapsed time
- persistent task state that should survive across turns or sessions
- long-running debugging, migration, or verification work
- explicit review checkpoints between implementation phases

Default flow:

```text
1. Clarify the goal or use the active Superpowers plan when one exists.
2. Split the work into atomic tasks with clear file ownership and verification.
3. Spawn Ruflo-tracked agents for independent tasks.
4. Keep sequential or tightly coupled work in the main agent.
5. Use the main agent as supervisor and final reviewer.
6. Store operational findings in Ruflo AgentDB.
```

Do not spawn Ruflo agents for docs-only edits, one-file fixes, simple config
changes, command output checks, formatting, linting, or tasks where all steps
must be performed sequentially.

#### Model Routing

Default to the least expensive model capable of completing the task accurately.

`AGENTS.md` cannot change the active Codex session model by itself. These rules
apply when deciding whether to stay inline, change the Codex model with the
Codex UI or CLI, or route work through an orchestration agent. Do not document
or request non-Codex vendor model aliases for Codex work.

| Task Type | Default Execution | Codex Model Guidance |
|-----------|-------------------|----------------------|
| Docs-only edits, ignore-file updates, typo fixes, command checks | Inline, no spawned agent | Keep current model; do not escalate |
| Targeted search, summarization, simple verification, low-risk cleanup | Inline first; spawned agent only if useful for persistence | Prefer `gpt-5.4-mini` when selecting a cheaper Codex model |
| Focused implementation, shell test updates, moderate debugging | Inline or orchestrated agent when parallelism or persistent task state helps | Use current default `gpt-5.5` unless a cheaper model is clearly enough |
| Multi-file design, architecture, migration strategy, security review, final review | Main-thread review or orchestrated agent with strongest reasoning | Use `gpt-5.5` with higher reasoning effort when available |

Escalate to `gpt-5.5` with higher reasoning effort only when:

- requirements are ambiguous
- architectural decisions are required
- security, authentication, or data integrity is affected
- changes span multiple subsystems
- repeated verification failures occur
- performing the final code review

Avoid stronger or higher-reasoning Codex models for:

- documentation-only work
- formatting or linting
- simple configuration changes
- trivial single-file edits
- repository status checks or command output inspection

Avoid spawning additional agents for the same low-risk task classes unless
persistent task state or parallelism is materially useful.

---

### 2. Test-Driven Development

This repository prefers TDD by default for non-trivial code changes.

Follow the Red → Green → Refactor cycle when practical:

1. Write a failing test.
2. Verify the test fails inside Ruflo's sandbox harness. If a subagent encounters sequential test loop failures, use the active debugging workflow; when Superpowers is already in use, route the telemetry into its `systematic-debugging` workflow.
3. Implement the minimum code required.
4. Refactor while keeping tests green.

For trivial changes, documentation-only edits, or config-only changes, use the most relevant verification command instead.

---

### 3. Code Review & Branch Completion

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
Applicable skills, including Superpowers when invoked
        ↓
Global ~/.codex/AGENTS.md
```

Project-specific overrides should be placed under the **Conventions** section whenever possible.

---

## Memory Management

### Durable Knowledge

- Generalizable learnings and correction logs should be written directly to the personal Obsidian vault using the Obsidian MCP integration when available.
- **Collision Prevention:** Only the primary supervising agent is authorized to write or append to the Obsidian vault via MCP tools to prevent parallel write-collision locks. Subagents must never call Obsidian tools.

### Execution Memory

- Persistent execution history, trajectory learning, and long-term operational memory are managed by Ruflo through its AgentDB vector storage layers when available. Subagents will exclusively log their operational discoveries and context here.
