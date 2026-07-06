# Codex Agent Stack Setup

Use this guide to configure LeanCTX, Context7, Caveman, and Superpowers so
`AGENTS.md` files work without tool-routing conflicts.

## Goal

- LeanCTX owns file reading, code search, tree scans, and shell-output
  compression.
- Context7 owns current documentation lookup for libraries, frameworks, SDKs,
  APIs, CLIs, and cloud services.
- Caveman owns conversational compression only.
- Superpowers owns development workflows only when the user manually invokes
  that workflow in a session.

Do not make every layer responsible for every task. Conflicts happen when
context tools, hooks, skills, and instruction files all try to control the same
surface.

## Required Codex Files

Global Codex files:

```text
~/.codex/AGENTS.md
~/.codex/config.toml
~/.config/lean-ctx/config.toml
```

Project files:

```text
AGENTS.md
.gitignore
```

Use `.codexignore` only as a repo-local convention when local tooling is
verified to consume it; current Codex behavior should not depend on it for
context exclusion.

## Codex MCP Configuration

Configure LeanCTX as its own MCP server in `~/.codex/config.toml`. Use distinct
server names for each MCP integration and let Codex namespace the tools.

```toml
[mcp_servers.lean-ctx]
command = "/usr/local/bin/lean-ctx"
args = []

[mcp_servers.lean-ctx.env]
LEAN_CTX_DATA_DIR = "/Users/burljohnson/.local/share/lean-ctx"
```

Do not use a shared wrapper that hides which server owns which tools.

## LeanCTX Setup

Use LeanCTX's interactive setup command with this stack's unattended answers:

```bash
cd "$(git rev-parse --show-toplevel)"
printf "y\nn\ny\nmax\ny\n" | lean-ctx setup
cd "$HOME"
lean-ctx config set path_jail false --yes
lean-ctx doctor --fix
lean-ctx proxy enable
lean-ctx proxy codex-chatgpt on
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
home directory before continuing, disable the path jail, enable the proxy, and
turn on Codex ChatGPT proxy routing after setup.

Verify LeanCTX:

```bash
lean-ctx doctor
lean-ctx doctor overhead
lean-ctx tools health
```

Expected outcome:

- LeanCTX is on `PATH`.
- Codex MCP config includes `lean-ctx`.
- Fixed overhead is under the configured token budget.

## Context7 Setup

Context7 is the documentation lookup layer. Configure it separately from
LeanCTX.

Before running the installer, create a Context7 API key and expose it to the
install session:

```bash
export CONTEXT7_API_KEY="your-context7-api-key"
```

Configure Context7 for Codex with:

```bash
codex mcp add context7 -- npx -y @upstash/context7-mcp --api-key "$CONTEXT7_API_KEY"
```

Do not commit the API key to any repository. If `CONTEXT7_API_KEY` is missing,
the installer must stop before Context7 configuration and print these
instructions.

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

## Ownership Matrix

| Surface | Owner | Use For | Do Not Use For |
|---------|-------|---------|----------------|
| `AGENTS.md` | Codex instructions | Durable repo behavior, commands, verification, routing policy | Runtime databases or secrets |
| LeanCTX MCP | Context and reads | `ctx_read`, `ctx_tree`, `ctx_search`, compressed shell output | Agent coordination |
| Context7 MCP | Current docs | Library, framework, SDK, API, CLI, and cloud-service documentation | Local code search or business logic debugging |
| Caveman | Response style | Concise narrative | Code, commands, errors, routing |
| Superpowers | Manual dev workflow | Explicitly requested implementation and review workflows | Automatic activation for every software task |
| `.codexignore` | Local convention | Token-heavy or sensitive file exclusions only when verified local tooling consumes it | Codex-native context exclusion |
| `.gitignore` | Source-control boundary | Keeping generated files untracked | Agent context by itself |

## Model Routing For Codex

Codex model selection should use Codex/OpenAI model names, not Claude model
aliases.

Default routing:

| Task Type | Execution | Model Guidance |
|-----------|-----------|----------------|
| Docs-only edits, ignore files, typo fixes, command checks | Inline | Keep current model; do not escalate |
| Search, summarization, simple verification, low-risk cleanup | Inline first | Use `gpt-5.4-mini` when selecting a cheaper model |
| Focused implementation, shell test updates, moderate debugging | Inline, or subagent when persistence helps | Use current default `gpt-5.5` unless a cheaper model is clearly enough |
| Multi-file design, architecture, migration strategy, security review, final review | Main thread or strongest available subagent | Use `gpt-5.5` with higher reasoning effort |

Escalate only when:

- requirements are ambiguous
- architecture is affected
- security, permissions, secrets, or data integrity are affected
- changes span multiple subsystems
- cheaper attempts repeatedly fail verification
- final review is for a risky change

Avoid stronger or higher-reasoning models for:

- documentation-only work
- formatting, linting, or shell syntax checks
- simple configuration changes
- trivial single-file edits
- repository status checks or command output inspection

## Verification Checklist

After setup changes:

```bash
lean-ctx doctor
lean-ctx doctor overhead
lean-ctx tools health
codex mcp list
git diff --check
```

Also run this repository's own checks after editing installer behavior:

```bash
bash -n scripts/*.sh tests/*.sh
for test in tests/*.sh; do bash "$test"; done
```
