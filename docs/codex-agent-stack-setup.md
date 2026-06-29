# Codex Agent Stack Setup

Use this guide to configure LeanCTX, Ruflo, Caveman, and Superpowers so
`AGENTS.md` files work without tool-routing conflicts.

## Goal

- LeanCTX owns file reading, code search, tree scans, and shell-output
  compression.
- Ruflo owns persistent orchestration, swarm state, AgentDB memory, and
  long-running agent coordination.
- Caveman owns conversational compression only.
- Superpowers owns development workflows only when software development work is
  requested.

Do not make every layer responsible for every task. Conflicts happen when
LeanCTX, Ruflo, hooks, skills, and instruction files all try to control the same
surface.

## Required Codex Files

Global Codex files:

```text
~/.codex/AGENTS.md
~/.codex/config.toml
~/.config/lean-ctx/config.toml
~/.ruflo/
```

Project files:

```text
AGENTS.md
.codexignore
.gitignore
```

Do not keep Ruflo runtime state inside project checkouts by default. If Ruflo
recreates compatibility paths because it expects Claude-flow names internally,
make those paths ignored symlinks back to `~/.ruflo/` rather than real project
databases:

```text
.ruflo -> ~/.ruflo
.claude-flow -> .ruflo/claude-flow
.swarm -> .ruflo/swarm
agentdb.rvf -> .ruflo/agentdb.rvf
agentdb.rvf.lock -> .ruflo/agentdb.rvf.lock
ruvector.db -> .ruflo/ruvector.db
```

The preferred clean state is no project-level `.ruflo`, `.claude-flow`,
`.swarm`, `agentdb.rvf`, `agentdb.rvf.lock`, or `ruvector.db` paths at all.
Keep ignore rules for those names so accidental recreations stay out of source
control and agent context.

## Codex MCP Configuration

Configure LeanCTX and Ruflo as separate MCP servers in `~/.codex/config.toml`.
Use distinct server names and let Codex namespace the tools.

```toml
[mcp_servers.lean-ctx]
command = "/usr/local/bin/lean-ctx"
args = []

[mcp_servers.lean-ctx.env]
LEAN_CTX_DATA_DIR = "/Users/burljohnson/.local/share/lean-ctx"

[mcp_servers.ruflo]
command = "npx"
args = ["-y", "ruflo@latest", "mcp", "start"]
```

Do not use a shared wrapper that hides which server owns which tools.

## LeanCTX Setup

Use LeanCTX's real tool profile command:

```bash
lean-ctx tools minimal
```

Do not document or run:

```bash
lean-ctx config set mode lazy
```

That key is not valid for the installed LeanCTX version in this environment.

Verify LeanCTX:

```bash
lean-ctx doctor
lean-ctx doctor overhead
lean-ctx tools health
```

Expected outcome:

- LeanCTX is on `PATH`.
- Codex MCP config includes `lean-ctx`.
- Tool profile is `minimal`.
- Fixed overhead is under the configured token budget.

## Ruflo Setup

Ruflo should be available to Codex through MCP first. Use CLI status as a
secondary diagnostic, because Ruflo MCP and Ruflo daemon status can disagree.

Verify Codex-facing Ruflo:

```bash
npx --yes ruflo@latest init check
npx --yes ruflo@latest mcp tools
```

Expected MCP tools include:

```text
agent_spawn
agent_list
swarm_init
swarm_status
memory_store
memory_retrieve
hooks_pre-command
hooks_post-command
```

Use Ruflo for:

- persistent agent records
- swarm state
- AgentDB memory
- durable task assignment
- cross-session orchestration

Do not use Ruflo for:

- formatting
- linting
- normal file reads
- one-off docs edits
- trivial command checks

Ruflo v3.14.x does not expose these commands:

```bash
ruflo format <file>
ruflo lint
```

Use project-native checks instead.

## Caveman Setup

Caveman is a communication compression layer, not a tool router.

Use it for:

- concise narrative
- compact progress updates
- short summaries

Do not use it to compress:

- code
- file paths
- exact CLI commands
- API names
- flags
- errors
- test output that must be quoted exactly

In `AGENTS.md`, describe Caveman as response-style compression only. Do not let
it override verification, routing, model selection, or safety rules.

## Superpowers Setup

Superpowers is a workflow layer for software development tasks.

Invoke Superpowers automatically only for:

- writing or editing code
- implementing features
- fixing bugs
- refactoring
- testing
- code review
- creating or editing skills

Do not auto-invoke it for:

- ordinary questions
- explanations
- configuration checks
- local machine troubleshooting
- installation verification
- process inspection
- docs-only cleanup unless the user explicitly requests the workflow

This keeps cheap tasks cheap and prevents heavy process scaffolding from
crowding the context.

## Ownership Matrix

| Surface | Owner | Use For | Do Not Use For |
|---------|-------|---------|----------------|
| `AGENTS.md` | Codex instructions | Durable repo behavior, commands, verification, routing policy | Runtime databases or secrets |
| LeanCTX MCP | Context and reads | `ctx_read`, `ctx_tree`, `ctx_search`, compressed shell output | Agent orchestration |
| Ruflo MCP | Orchestration | Agents, swarms, task state, AgentDB memory | Formatting, linting, raw file reads |
| Caveman | Response style | Concise narrative | Code, commands, errors, routing |
| Superpowers | Dev workflow | Non-trivial implementation and review workflows | Status checks, docs-only edits, simple config checks |
| `.codexignore` | Agent context boundary | Excluding token-heavy or sensitive files from Codex context | Source-control policy |
| `.gitignore` | Source-control boundary | Keeping runtime state and generated files untracked | Agent context by itself |

## Model Routing For Codex

Codex model selection should use Codex/OpenAI model names, not Claude model
aliases.

Default routing:

| Task Type | Execution | Model Guidance |
|-----------|-----------|----------------|
| Docs-only edits, ignore files, typo fixes, command checks | Inline | Keep current model; do not escalate |
| Search, summarization, simple verification, low-risk cleanup | Inline first | Use `gpt-5.4-mini` when selecting a cheaper model |
| Focused implementation, shell test updates, moderate debugging | Inline or Ruflo when persistence helps | Use current default `gpt-5.5` unless a cheaper model is clearly enough |
| Multi-file design, architecture, migration strategy, security review, final review | Main thread or Ruflo with strongest reasoning | Use `gpt-5.5` with higher reasoning effort |

Escalate only when:

- requirements are ambiguous
- architecture is affected
- security, permissions, secrets, or data integrity are affected
- changes span multiple subsystems
- cheaper attempts repeatedly fail verification
- final review is for a risky change

Avoid stronger or higher-reasoning models for:

- docs-only work
- formatting
- linting
- simple configuration
- repository status checks

## Conflict Prevention Rules

1. Use LeanCTX before native file reads when LeanCTX MCP tools are available.
2. Use Ruflo only when persistent orchestration or memory is useful.
3. Keep Caveman out of code, command, and error text.
4. Keep Superpowers limited to software development workflows.
5. Keep runtime state ignored and out of agent context.
6. Verify claims with real commands before documenting them.
7. Prefer project-native checks over invented harness commands.

## Verification Checklist

Run these after setup:

```bash
lean-ctx doctor overhead
lean-ctx tools health
npx --yes ruflo@latest init check
npx --yes ruflo@latest mcp tools
git check-ignore -v .ruflo .claude-flow .swarm agentdb.rvf ruvector.db
git diff --check -- AGENTS.md .codexignore .gitignore
```

Restart Codex after changing `~/.codex/config.toml` or LeanCTX tool profiles.

## References

- Codex manual: `https://developers.openai.com/codex/codex-manual.md`
- Codex model guidance: `https://developers.openai.com/codex/models.md`
- LeanCTX local verification: `lean-ctx doctor`, `lean-ctx tools health`
- Ruflo local verification: `npx --yes ruflo@latest --help`
