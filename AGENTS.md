# Project AGENTS.md

> Project-specific instructions. Inherits global behavior from `~/.codex/AGENTS.md`.

## Project Info

### Purpose

macOS-only installer for Codex and Claude Code instruction files plus Git hook
automation that seeds project-level instruction files into Git repositories.

### Language / Framework

Bash, Markdown instruction templates, Git hook scripts, and shell-based
regression tests.

### Key Entry Points

`scripts/install.sh`, `scripts/bootstrap.sh`,
`scripts/seed-project-instructions.sh`, `templates/AGENTS.global.md`,
`templates/AGENTS.project-template.md`, `templates/CLAUDE.global.md`,
`templates/CLAUDE.project-template.md`, and `tests/*.sh`.

---

## Development Commands

| Task | Command |
|------|---------|
| **Build** | No compiled build; scripts are interpreted. |
| **Test** | `for test in tests/*.sh; do bash "$test"; done` |
| **Format** | No project-native formatter is configured. Preserve existing shell and Markdown style. |
| **Lint / Typecheck** | `bash -n scripts/*.sh tests/*.sh` |
| **Run** | `bash scripts/install.sh --dry-run --non-interactive --tools both` |

## Verification Requirements

After code changes:

1. Run `bash -n scripts/*.sh tests/*.sh`.
2. Run `for test in tests/*.sh; do bash "$test"; done`.
3. Run the repository scan requested by the task when scope changes affect removed setup surfaces.
4. Run `git diff --check`.
5. Report failures directly instead of claiming success.

### Verification Hooks

Do **not** assume Ruflo provides formatter or linter commands.

Ruflo v3.14.x does not expose `format` or `lint` as CLI commands, so agents
must **not** call:

```bash
ruflo format <file>
ruflo lint
```

Instead:

- Use the project-native shell syntax check and shell test commands listed
  above.
- Use `git diff --check` for Markdown, ignore-file, and docs-only changes.
- Use Ruflo only for supported harness, hook, memory, MCP, swarm, or
  orchestration commands confirmed by `npx --yes ruflo@latest --help`.

### Required Verification Flow

After editing files:

```text
1. Run the relevant project-native check for the changed files.
2. Run shell syntax checks when scripts or tests changed.
3. Run the shell regression suite when installer, hook, or template behavior changed.
4. Review the diff.
5. Declare completion only after verification passes or clearly report failures.
```

For documentation-only edits, `git diff --check -- <changed-files>` is the
minimum required verification.

---

## Conventions

### Testing

- Tests live under `tests/*.sh` and run with Bash.
- Tests create temporary homes and repositories so installer behavior is checked
  without mutating the real machine.
- Cover installer safety, tool selection, Git template hook behavior,
  current-repo hook wrapping, seeding, uninstall, and bootstrap checksum checks.

### Coding Style & Architecture

- Keep scripts POSIX/Bash-style and aligned with the existing shell patterns.
- Keep installer behavior in `scripts/install.sh`; keep project-file seeding in
  `scripts/seed-project-instructions.sh`; keep bootstrap download/checksum
  behavior in `scripts/bootstrap.sh`.
- Keep reusable instruction text in `templates/*.md` and avoid hardcoding
  duplicate instruction bodies in scripts.
- Maintain the split between global instruction templates and project template
  files for both Codex and Claude Code.
- Prefer explicit, idempotent managed-marker updates for Git hooks and generated
  instruction files.
- Avoid adding package-manager, plugin, protocol-server, or external CLI setup
  paths unless the repository scope is explicitly expanded.

### Coding Standards

- Keep the installer Bash-only and macOS-focused.
- Do not add package-manager, plugin, skill, protocol-server, or external CLI setup paths.
- Preserve user-owned files by default. Overwrite only when an explicit
  overwrite flag is provided, and create backups before replacement.
- Keep hooks idempotent by using managed markers.
- Keep hooks limited to `AGENTS.md` and `CLAUDE.md` project instruction files.
- Do not delete repo-local instruction files during uninstall.

### Project-Specific Rules

- Interactive install asks whether to configure Codex, Claude Code, or both.
- Non-interactive install requires `--tools codex`, `--tools claude`, or
  `--tools both`.
- Future repository support is provided through Git template hooks under
  `~/.agents/git-template/hooks/`.
- Existing repositories are configured only when the user passes `--repo` or
  accepts the interactive current-repo prompt.

### Codex, Ruflo, and LeanCTX Runtime Notes

- This checkout is used to validate Codex-focused instruction and hook setup.
  Keep repo guidance centered on Codex unless the task explicitly targets
  Claude Code templates.
- Use Ruflo MCP tools for persistent Codex agent, swarm, task, and memory
  workflows. Do not copy Claude Code generated `Agent(...)`, `SendMessage(...)`,
  or `claude mcp add ...` instructions into `AGENTS.md`.
- Verify Codex-facing Ruflo availability with `npx --yes ruflo@latest init check`,
  `npx --yes ruflo@latest mcp tools`, and the active Codex MCP tool list.
  Ruflo CLI daemon and hook status output can disagree with the MCP tool
  surface, so report that distinction instead of treating one status command as
  authoritative.
- LeanCTX tool-footprint setup for this environment uses `lean-ctx tools minimal`.
  Do not document `lean-ctx config set mode lazy` unless that command has been
  re-verified against the installed LeanCTX version.
- Treat `~/.ruflo/` as the preferred Ruflo runtime state directory. It should
  live next to `~/.codex/`, not inside this project.
- Do not keep project-level `.ruflo`, `.claude-flow`, `.swarm`,
  `agentdb.rvf`, `agentdb.rvf.lock`, or `ruvector.db` paths by default.
  If Ruflo recreates or requires those compatibility paths, keep them ignored
  and point them back to `~/.ruflo/` rather than storing real databases in this
  repository.

---

## Token-Saver File Boundaries

Unless required for the current task, avoid loading generated artifacts,
dependency directories, logs, coverage reports, build outputs, secrets, binary
assets, and local databases.

Project-specific exclusions should be maintained through `.gitignore`,
`.codexignore`, `.claude/settings.json`, and related ignore files.

This repository maintains these context-boundary files:

- `.gitignore`
- `.codexignore`
- `.claude/settings.json`
- `.copilotignore`

If this repository requires broader or narrower exclusions, update the local
ignore files and verify them with `git check-ignore -v`.

---

# Development Workflow

This repository inherits the global session requirements:

- Automatically load LeanCTX for AST-aware workspace scoping.
- Automatically enable the Ruflo harness for daemon workers and trajectory
  learning.
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

- Feed the generated implementation plan files directly into the `ruflo-swarm`
  engine for execution.
- **Execution Topology:** Allow Ruflo to execute independent, parallel subagents
  across the workspace using isolated git worktrees. Highly dependent tasks or
  sequential logic changes must be processed linearly.
- Use review checkpoints at the end of major milestones.
- Keep each subagent tightly focused on one atomic task.

#### Runtime State Boundaries

- Keep `~/.ruflo/` as local machine runtime state, and keep `.ruflo`,
  `.claude-flow`, `.swarm`, `agentdb.rvf`, `agentdb.rvf.lock`, and
  `ruvector.db` out of source control and agent context.
- Do not move or delete runtime databases while Ruflo or Codex MCP processes
  have them open.

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
Codex UI or CLI, or route work through a Ruflo agent. Do not document or request
non-Codex vendor model aliases for Codex work.

| Task Type | Default Execution | Codex Model Guidance |
|-----------|-------------------|----------------------|
|-----------|-------------------|----------------------|
| Docs-only edits, ignore-file updates, typo fixes, command checks | Inline, no spawned agent | Keep current model; do not escalate |
| Targeted search, summarization, simple verification, low-risk cleanup | Inline first; spawned agent only if useful for persistence | Prefer `gpt-5.4-mini` when selecting a cheaper Codex model |
| Focused implementation, shell test updates, moderate debugging | Inline or Ruflo agent when parallelism or persistent task state helps | Use current default `gpt-5.5` unless a cheaper model is clearly enough |
| Multi-file design, architecture, migration strategy, security review, final review | Main-thread review or Ruflo agent with strongest reasoning | Use `gpt-5.5` with higher reasoning effort when available |

Escalate to `gpt-5.5` with higher reasoning effort only when:

- requirements are ambiguous or internally conflicting
- architectural decisions are required
- security, authentication, permissions, secrets, or data integrity are affected
- changes span multiple subsystems or ownership boundaries
- cheaper attempts fail verification repeatedly
- performing final review for a risky change

Avoid stronger or higher-reasoning Codex models for:

- documentation-only work
- formatting, linting, or shell syntax checks
- simple configuration changes
- trivial single-file edits
- repository status checks or command output inspection

Avoid spawning additional agents for the same low-risk task classes unless
persistent task state or parallelism is materially useful.

When using Ruflo, record the routing reason in the task or agent prompt so the
model choice is auditable later.

---

### 2. Test-Driven Development

This repository prefers TDD by default for non-trivial code changes.

Follow the Red -> Green -> Refactor cycle when practical:

1. Write a failing test.
2. Verify the test fails inside Ruflo's sandbox harness. If a subagent
   encounters sequential test loop failures, use the active debugging workflow;
   when Superpowers is already in use, route the telemetry into its
   `systematic-debugging` workflow.
3. Implement the minimum code required.
4. Refactor while keeping tests green.

For trivial changes, documentation-only edits, or config-only changes, use the
most relevant verification command instead.

For non-trivial installer or hook behavior changes, add or update a shell test
first when practical.

For docs-only and ignore-boundary changes, verify with `git diff --check` and
`git check-ignore -v` instead of running unrelated checks.

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

- Review `git diff` before reporting completion.
- Mention unrelated dirty files separately; do not revert or normalize them
  unless explicitly asked.

---

## Instruction Precedence

Instruction precedence is:

```text
Direct user request
        ↓
Local project AGENTS.md
        ↓
Global ~/.codex/AGENTS.md
        ↓
Applicable skills and tool instructions
```

Project-specific overrides should be placed under **Conventions** or
**Development Workflow** whenever possible.

---

## Memory Management

### Durable Knowledge

- Generalizable learnings and correction logs should be written directly to the
  personal Obsidian vault using the Obsidian integration when available.
- Project-specific durable notes for this repository belong under
  `Projects/Token Saver Setup` in the Obsidian vault.
- Only the primary supervising agent is authorized to write or append to the
  Obsidian vault to prevent parallel write-collision locks.

### Execution Memory

- Ruflo AgentDB and RuVector state for this checkout is local runtime state, not
  source.
- Keep persistent execution history under `~/.ruflo/` next to `~/.codex/`.
  Project-level Ruflo paths should stay absent unless Ruflo requires ignored
  compatibility links for root-level files or `.claude-flow` / `.swarm`.
