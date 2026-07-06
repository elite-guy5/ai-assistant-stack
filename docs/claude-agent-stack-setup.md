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
- Context7 handles current documentation lookup for libraries, frameworks,
  SDKs, APIs, CLIs, and cloud services.
- Caveman remains response compression only.
- Superpowers remains a manually invoked software-development workflow layer.

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
and Context7. Do not put Claude MCP config in `~/.codex/config.toml`.

Recommended server separation:

```text
lean-ctx: context reads, search, shell compression
context7: current documentation lookup
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

Use LeanCTX's interactive setup command with this stack's unattended answers:

```bash
cd "$(git rev-parse --show-toplevel)"
printf "y\nn\ny\nmax\ny\n" | lean-ctx setup
cd "$HOME"
lean-ctx config set path_jail false --yes
lean-ctx doctor --fix
claude mcp add --scope user --transport stdio lean-ctx -- lean-ctx
# Optional: enable Claude/Anthropic proxy routing.
ANTHROPIC_API_KEY="your-anthropic-api-key" lean-ctx proxy enable
```

Do not force a custom tool profile or document invalid config keys:

```bash
lean-ctx tools minimal
lean-ctx config set mode lazy
```

The answers enable IDE config access, decline anonymous telemetry, enable
auto-updates, select `max` compression, and enable result archiving. Run setup
from an active Git project so LeanCTX can use its default project-root
detection. Do not set `LEAN_CTX_PROJECT_ROOT` manually. Return to the user's
home directory before continuing and disable the path jail after setup. Enable
Claude/Anthropic proxy routing only when the user opts in and
`ANTHROPIC_API_KEY` is available.

Verify:

```bash
lean-ctx doctor
lean-ctx doctor overhead
lean-ctx tools health
```

## Context7 For Claude Code

Context7 is the documentation lookup layer for current library, framework, SDK,
API, CLI, and cloud-service docs.

Before running the installer, create a Context7 API key and expose it to the
install session:

```bash
export CONTEXT7_API_KEY="your-context7-api-key"
```

Configure Context7 for Claude Code with:

```bash
claude mcp add --scope user --header "CONTEXT7_API_KEY: $CONTEXT7_API_KEY" --transport http context7 https://mcp.context7.com/mcp
```

Do not commit the API key to any repository. If `CONTEXT7_API_KEY` is missing,
the installer must stop before Context7 configuration and print these
instructions.

## Claude Hooks

Claude hooks run at lifecycle events such as tool use, prompt submit, session
start, compaction, stop, notification, and subagent events.

Use hooks for enforcement that `CLAUDE.md` cannot guarantee:

- blocking dangerous commands
- preventing reads of secret files
- formatting after edits when a real formatter exists
- restoring context after compaction
- recording task events

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

Superpowers is a workflow layer for software development tasks. Invoke it
manually in a session when the task needs that workflow.

Use Superpowers for:

- implementation planning
- executing an approved plan
- systematic debugging
- test-driven development
- requesting or receiving code review

Do not auto-invoke Superpowers just because the task is software development.
The user should explicitly request the workflow, or an already-active
Superpowers workflow should require the next Superpowers skill.

When the installer adds Superpowers, it preserves the plugin but rewrites cached
Superpowers skill descriptions to require explicit manual invocation. This keeps
the skills available without advertising them as automatic triggers for normal
sessions. It also replaces the cached `using-superpowers` body so manual
invocation does not reintroduce upstream automatic routing rules.

## Claude Model Routing

Claude Code model routing should use Claude model names and availability for
the active Claude account or API provider. Keep this separate from Codex model
routing.

Recommended policy:

| Task Type | Guidance |
|-----------|----------|
| Docs-only edits, ignore-file updates, typo fixes, command checks | Use the current model or a cheaper model when available |
| Targeted search, summarization, simple verification, low-risk cleanup | Use a low-cost model when accuracy risk is low |
| Focused implementation, shell test updates, moderate debugging | Use a daily coding model |
| Planning plus implementation where planning needs stronger reasoning | Use plan mode when available |
| Multi-file design, architecture, migration strategy, security review, final risky review | Use the strongest available model when justified |

When model availability is unclear, use Claude Code's `/model` picker or current
settings instead of guessing exact model IDs.

## Verification Checklist

After setup changes:

```bash
lean-ctx doctor
lean-ctx doctor overhead
lean-ctx tools health
git diff --check
```

Also run this repository's own checks after editing installer behavior:

```bash
bash -n scripts/*.sh tests/*.sh
for test in tests/*.sh; do bash "$test"; done
```
