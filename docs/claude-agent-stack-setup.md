# Claude Agent Stack Setup

Use this guide only for Claude Code. Keep it separate from Codex setup because
Claude Code uses different config files, settings scopes, hooks, skills, and
model names.

## Goal

- `CLAUDE.md` holds Claude Code project and global instructions.
- Claude Code settings hold hooks, permissions, status line, environment, and
  optional tool configuration.
- MCP servers are registered through Claude Code MCP configuration, not
  `~/.codex/config.toml`.
- LeanCTX handles file and context compression.
- Ruflo handles orchestration, swarm state, AgentDB memory, and hooks when
  explicitly configured for Claude Code.
- Caveman remains response compression only.
- Superpowers remains a software-development workflow layer.

## Required Claude Files

Global Claude Code files:

```text
~/.claude/CLAUDE.md
~/.claude/settings.json
```

Project Claude Code files:

```text
CLAUDE.md
.claude/settings.json
.claude/skills/
.mcp.json
```

Use `.claude/settings.local.json` only for local, unshared permissions and
secrets boundaries. Do not commit local machine credentials, private tokens, or
machine-specific settings.

## Settings Scopes

Claude Code settings are scoped. Use the smallest scope that matches the
behavior:

| Scope | Use For |
|-------|---------|
| User settings | Personal defaults in `~/.claude/settings.json` |
| Project settings | Team-shared project behavior in `.claude/settings.json` |
| Local project settings | Machine-local permissions in `.claude/settings.local.json` |
| Managed settings | Organization policy, if applicable |

Prefer project settings for shared hook behavior and local settings for local
denies, secrets, and machine-specific allowances.

## CLAUDE.md Setup

Use `~/.claude/CLAUDE.md` for global Claude behavior and project `CLAUDE.md`
for repository-specific behavior.

Keep `CLAUDE.md` concise:

- commands
- verification requirements
- repo architecture
- tool-routing rules
- context boundaries
- memory policy

Do not copy Codex-only TOML configuration or OpenAI model routing into
`CLAUDE.md`.

## MCP Setup

Claude Code MCP setup is separate from Codex MCP setup.

Use Claude MCP commands or Claude MCP config files for servers such as LeanCTX
and Ruflo. Do not put Claude MCP config in `~/.codex/config.toml`.

Recommended server separation:

```text
lean-ctx: context reads, search, shell compression
ruflo: orchestration, agent state, memory, hooks
```

Verify MCP from Claude Code with the Claude MCP tooling available in that
environment. Do not assume a server is active just because the binary is
installed.

## LeanCTX For Claude Code

Use LeanCTX for:

- file reads
- code search
- tree scans
- compressed command output

Use the real installed command for footprint control:

```bash
lean-ctx tools minimal
```

Do not document:

```bash
lean-ctx config set mode lazy
```

Verify:

```bash
lean-ctx doctor
lean-ctx doctor overhead
lean-ctx tools health
```

If Claude Code hooks also run shell commands, do not let LeanCTX shell hooks and
Ruflo shell hooks both claim ownership of the same lifecycle event without a
clear order.

## Ruflo For Claude Code

Use Ruflo for:

- persistent agents
- task and swarm coordination
- AgentDB memory
- status line and hook helpers when explicitly configured

Do not assume Ruflo provides formatter or linter commands:

```bash
ruflo format <file>
ruflo lint
```

Use project-native format, lint, typecheck, and test commands instead.

Verify Ruflo:

```bash
npx --yes ruflo@latest --help
npx --yes ruflo@latest init check
npx --yes ruflo@latest mcp tools
```

If Claude Code settings call helper scripts such as
`.claude/helpers/hook-handler.cjs`, confirm those files exist before enabling
hooks that reference them.

## Claude Hooks

Claude hooks run at lifecycle events such as tool use, prompt submit, session
start, compaction, stop, notification, and subagent events.

Use hooks for enforcement that `CLAUDE.md` cannot guarantee:

- blocking dangerous commands
- preventing reads of secret files
- formatting after edits when a real formatter exists
- restoring context after compaction
- recording task and memory events

Do not use hooks for vague guidance. Put guidance in `CLAUDE.md`; put
mechanical enforcement in hooks.

Keep hook commands small, deterministic, and easy to debug. Every hook command
should be safe to run repeatedly.

## Claude Skills

Use `.claude/skills/<skill-name>/SKILL.md` for reusable procedures that would
otherwise bloat `CLAUDE.md`.

Good skill candidates:

- debugging workflow
- release checklist
- security review workflow
- project-specific deployment procedure

Poor skill candidates:

- one-off notes
- secrets
- volatile machine state
- broad policy that belongs in `CLAUDE.md`

## Caveman For Claude Code

Caveman remains response compression only.

Use it for:

- concise narrative
- compact status updates
- low-token summaries

Never compress:

- code
- commands
- flags
- file paths
- exact errors
- test output that must remain verbatim

## Superpowers For Claude Code

Use Superpowers only for software development work:

- implementation
- bug fixing
- refactoring
- testing
- code review
- skill creation or editing

Do not invoke it automatically for:

- installation checks
- local process inspection
- simple documentation edits
- ordinary explanations
- config status checks

This prevents unnecessary workflow overhead and token use.

## Claude Model Routing

Claude Code model routing should use Claude model names and availability for
the active Claude account or API provider. Keep this separate from Codex model
routing.

Recommended policy:

- Use the cheapest Claude model that can complete the task accurately.
- Use cheaper or faster models for documentation, search, summaries, and simple
  checks.
- Use stronger reasoning models for architecture, security, data integrity,
  cross-module changes, and final risky reviews.
- Do not put OpenAI model names such as `gpt-5.5` or `gpt-5.4-mini` into Claude
  model routing instructions.

When in doubt, ask Claude Code's model selector or configuration for available
models instead of guessing model IDs.

## Conflict Prevention Rules

1. Keep Codex and Claude config paths separate.
2. Keep LeanCTX responsible for context and reads.
3. Keep Ruflo responsible for persistent orchestration and memory.
4. Keep Caveman responsible for prose compression only.
5. Keep Superpowers responsible for software-development workflows only.
6. Keep hooks deterministic and narrowly scoped.
7. Keep runtime databases ignored and out of agent context.
8. Verify helper files exist before enabling hooks that reference them.

## Verification Checklist

Run these after Claude setup:

```bash
claude --version
lean-ctx doctor
lean-ctx doctor overhead
npx --yes ruflo@latest init check
npx --yes ruflo@latest mcp tools
```

Then verify expected shared files:

```bash
test -f ~/.claude/CLAUDE.md
test -f ~/.claude/settings.json
test -f .claude/settings.json
```

Restart Claude Code after changing settings, MCP servers, hooks, or skills.

## References

- Claude Code settings: `https://docs.anthropic.com/en/docs/claude-code/settings`
- Claude Code hooks: `https://docs.anthropic.com/en/docs/claude-code/hooks`
- Claude Code hook guide: `https://docs.anthropic.com/en/docs/claude-code/hooks-guide`
- Claude Code MCP: `https://docs.anthropic.com/en/docs/claude-code/mcp`
- Claude Code skills: `https://docs.anthropic.com/en/docs/claude-code/skills`
- Claude Code memory: `https://docs.anthropic.com/en/docs/claude-code/memory`
