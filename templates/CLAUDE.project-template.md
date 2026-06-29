# Project CLAUDE.md

> Project-specific Claude Code instructions. Inherits global behavior from `~/.claude/CLAUDE.md`.

Claude Code reads this file as persistent project context. Use `.claude/settings.json`, `.claude/settings.local.json`, `.mcp.json`, and hooks for technical enforcement.

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

Ruflo v3.14.x does not expose `format` or `lint` as CLI commands, so agents must **not** call:

```bash
ruflo format <file>
ruflo lint
```

Instead:

- Use the project-native formatter after edits.
- Use the project-native lint, typecheck, and test commands before declaring work complete.
- Use Ruflo only for supported harness, hook, memory, MCP, swarm, or orchestration commands confirmed by:

```bash
npx --yes ruflo@latest --help
```

### Required Verification Flow

After editing files:

```text
1. Run the project-native formatter for changed files, if configured.
2. Run the project-native lint or typecheck command, if configured.
3. Run the relevant tests.
4. Review the diff.
5. Declare completion only after verification passes or clearly report failures.
```

If the project has no formatter, linter, or tests yet, state that explicitly and verify with the best available command.

---

## Conventions

### Testing

> `<Testing conventions: test locations, frameworks, coverage expectations, and naming conventions>`

### Coding Style and Architecture

> `<Project-specific coding patterns, import rules, architecture, directory layout, and design conventions>`

### Claude Code Settings and Hooks

> `<Project-specific Claude Code settings, hook files, permission boundaries, MCP servers, and local-only setup notes>`

---

## Token-Saver File Boundaries

- Keep generated files, secrets, logs, coverage reports, dependency folders, local databases, and binary assets out of agent context by default.
- Maintain source-control exclusions through `.gitignore`.
- Maintain Claude Code context and permission boundaries through:
  - `.claude/settings.json`
  - `.claude/settings.local.json`
  - `CLAUDE.local.md`
  - `.mcp.json` when project-scoped MCP servers are shared

- If this repository also supports Codex, maintain Codex-specific exclusions through `.codexignore` and `AGENTS.md` without making Claude Code depend on Codex configuration.
- If this repository requires broader or narrower exclusions, update the local ignore and settings files instead of weakening global behavior.

---

# Development Workflow

This repository inherits the global Claude Code session requirements:

- Use LeanCTX for AST-aware workspace scoping and compressed context when available.
- Use Ruflo for daemon workers, task orchestration, swarm state, and trajectory learning when available and useful.
- Activate Caveman for conversational efficiency while keeping code, commands, paths, APIs, flags, and errors exact.
- Treat Superpowers as optional. Invoke it only when explicitly requested or
  when the active session already requires it.

When Superpowers is manually invoked, follow the active Superpowers skill
workflow, including its spec, plan, worktree, and verification requirements.

When Superpowers is not in use, follow this repository's normal development and
verification rules.

## Standard Workflow

### 1. Multi-Agent Orchestration

- Use Ruflo or Claude subagents only when persistent task state, parallel investigation, or isolation materially helps.
- Allow independent subagents to work in parallel only when their tasks do not share mutable files or sequential dependencies.
- Use review checkpoints at the end of major milestones.
- Keep each subagent tightly focused on one atomic task.
- Subagents must not write to the Obsidian vault.

#### Ruflo Dispatch Policy

Ruflo can be used with or without Superpowers. When Superpowers is manually
invoked for non-trivial, separable work, dispatch suitable Ruflo-tracked agents
or Claude subagents. When Superpowers is not in use, dispatch agents directly
when persistent task state, parallel investigation, isolation, or review
checkpoints materially help.

Spawn Ruflo-tracked agents when the plan includes any of these conditions:

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

Default to the least expensive Claude model capable of completing the task accurately.

`CLAUDE.md` can guide model choice, but model selection is controlled by Claude Code through `/model`, `claude --model`, `ANTHROPIC_MODEL`, the `model` setting, subagent frontmatter, and managed settings. Do not put Codex or OpenAI model names in Claude model-routing instructions.

| Task Type | Default Execution | Claude Model Guidance |
|-----------|-------------------|-----------------------|
| Docs-only edits, ignore-file updates, typo fixes, command checks | Inline, no spawned agent | Use the current model or `haiku` when selecting a cheaper model |
| Targeted search, summarization, simple verification, low-risk cleanup | Inline first; spawned agent only if useful for persistence | Prefer `haiku` or `sonnet` based on required accuracy |
| Focused implementation, shell test updates, moderate debugging | Inline or orchestrated agent when parallelism or persistent task state helps | Prefer `sonnet` for daily coding work |
| Planning plus implementation where planning needs stronger reasoning | Claude Code plan mode | Consider `opusplan` when available |
| Multi-file design, architecture, migration strategy, security review, final risky review | Main-thread review or orchestrated agent with strongest reasoning | Use `opus`, `best`, or `fable` when available and justified |

Escalate to a stronger Claude model only when:

- requirements are ambiguous
- architecture is affected
- security, authentication, permissions, secrets, or data integrity are affected
- changes span multiple subsystems
- cheaper attempts repeatedly fail verification
- final review is for a risky change

Avoid stronger or higher-cost Claude models for:

- documentation-only work
- formatting or linting
- simple configuration changes
- trivial single-file edits
- repository status checks or command output inspection

When model availability is unclear, use Claude Code's `/model` picker or current settings instead of guessing exact model IDs.

### 2. Test-Driven Development

This repository prefers TDD by default for non-trivial code changes.

Follow the Red, Green, Refactor cycle when practical:

1. Write a failing test.
2. Verify the test fails with the project-native test command.
3. Implement the minimum code required.
4. Refactor while keeping tests green.

For trivial changes, documentation-only edits, or config-only changes, use the most relevant verification command instead.

### 3. Code Review and Branch Completion

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

Use `CLAUDE.md` for behavioral guidance. Use Claude Code settings and hooks for enforceable restrictions.

Project-specific overrides should be placed under **Conventions** whenever possible.

---

## Memory Management

### Durable Knowledge

- Generalizable learnings and correction logs should be written directly to the personal Obsidian vault using the Obsidian MCP integration when available.
- Project-specific durable notes should go to the repository's documented Obsidian destination when one exists.
- Only the primary supervising agent is authorized to write or append to the Obsidian vault to prevent parallel write-collision locks.

### Claude Code Memory

- Use `CLAUDE.md` for durable project instructions that every session should read.
- Use `CLAUDE.local.md` for private local preferences.
- Use Claude Code auto memory for learned preferences and repeated corrections when enabled.
- Use `.claude/rules/` or skills for scoped procedures that would bloat this file.

### Execution Memory

- Persistent execution history, trajectory learning, and long-term operational memory are managed by Ruflo through its AgentDB vector storage layers when available.
- Subagents should record operational discoveries and context in AgentDB, not Obsidian.
