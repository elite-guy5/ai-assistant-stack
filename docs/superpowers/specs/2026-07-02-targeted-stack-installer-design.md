# Targeted Stack Installer Design

Date: 2026-07-02

## Summary

Convert this repository from an instruction-file installer into a one-command
installer that configures the full recommended agent stack for selected AI
client surfaces.

End users should not clone the repository. They should run one terminal command
that downloads the installer payload, prompts for selected targets when needed,
checks prerequisites before changing files, then installs and configures the
stack exactly as this repository recommends.

## Goals

- Provide a one-command install flow for end users.
- Let users select one or more supported target surfaces:
  - `codex-desktop`
  - `codex-vscode`
  - `claude-desktop`
  - `claude-vscode`
- Treat selected AI clients and VS Code as prerequisites, not install targets.
- Stop before changes when selected prerequisites are missing.
- Install and configure stack tools recommended by this repository:
  - LeanCTX
  - Context7
  - Ruflo
  - Caveman
  - Superpowers
  - instruction files, project templates, seeding script, and Git hooks
- Show every step performed.
- Log every step, selected target, derived tool selection, command, and failure
  with secrets redacted.
- Keep Ruflo runtime state rooted in `~/.ruflo`, not project directories.
- Update stack setup docs so Context7 is part of the recommended stack.
- Make Superpowers manual-only in a session.

## Non-Goals

- Do not install Codex, Claude, VS Code, or the VS Code host application.
- Do not guess package names, credentials, API keys, or unsupported setup paths.
- Do not move or delete active Ruflo runtime databases automatically.
- Do not add Windows or Linux support to this macOS-focused installer.
- Do not remove the existing instruction-file and Git hook behavior.

## Source Of Truth

The installer should follow this repository's setup recommendations first:

- `docs/codex-agent-stack-setup.md`
- `docs/claude-agent-stack-setup.md`
- `templates/AGENTS.global.md`
- `templates/CLAUDE.global.md`

Official upstream documentation may be used to verify and update those repo
recommendations, but installer behavior should be wired to the repository's
documented recommendations so the README, docs, templates, and scripts stay in
sync.

## One-Command Entry Point

The README should present a single terminal command as the primary install path:

```bash
curl -fsSL <repo-bootstrap-url> | bash
```

Non-interactive example:

```bash
curl -fsSL <repo-bootstrap-url> | bash -s -- --targets codex-desktop,codex-vscode
```

The bootstrap script should:

1. Download a temporary installer payload containing only required files.
2. Verify checksum when one is supplied.
3. Run `scripts/install.sh` with forwarded arguments.
4. Remove temporary files on exit.

Local clone instructions should remain available only for development.

## Target Selection

Add a new `--targets <list>` option.

Supported values:

- `codex-desktop`
- `codex-vscode`
- `claude-desktop`
- `claude-vscode`

Rules:

- `--targets` accepts comma-separated values.
- Interactive mode prompts for one or more target surfaces.
- Selected targets are printed before preflight.
- Selected targets are logged before preflight.
- Existing `--tools codex|claude|both` remains supported for backward
  compatibility.
- When `--targets` is provided, derive the instruction-file tool set:
  - any Codex target means Codex instruction files are installed
  - any Claude target means Claude instruction files are installed
  - both product families selected means both instruction-file sets are installed

## Preflight Behavior

No file, config, hook, or tool changes should happen until selected target
preflight passes.

Prerequisite checks:

- `codex-desktop` requires the Codex client or CLI to be installed.
- `codex-vscode` requires the Codex client or CLI and the VS Code `code` CLI.
- `claude-desktop` requires the Claude client or CLI to be installed.
- `claude-vscode` requires the Claude client or CLI and the VS Code `code` CLI.

If any selected prerequisite is missing, stop immediately with:

- selected target that failed
- missing executable or host app
- prerequisite list
- no-change statement
- log path

## Stack Install Order

After target preflight passes, install and configure stack tools in this order:

1. LeanCTX
2. Context7
3. Ruflo
4. Caveman
5. Superpowers
6. instruction files, templates, seeding script, and Git hooks

This order keeps context and documentation tools available before orchestration
and workflow layers are configured.

## Stack Tool Responsibilities

### LeanCTX

- Install if missing using the repo-documented method.
- Configure only for selected target families.
- Preserve the minimal tool footprint recommendation.
- Keep LeanCTX responsible for file reading, code search, tree scans, and shell
  output compression.

### Context7

- Add Context7 setup to both stack setup docs.
- Check for Context7 API credentials before configuration.
- If credentials are missing, stop before Context7 configuration.
- Print exact instructions for credential setup.
- Do not write placeholder API keys.
- Do not silently skip Context7 after it is selected through the stack flow.

### Ruflo

- Configure according to stack setup docs so it does not conflict with LeanCTX.
- Keep Ruflo responsible for orchestration, swarms, background workers, AgentDB,
  and persistent execution memory.
- Do not configure Ruflo as the file-reading, search, or shell-compression
  layer.
- Ensure runtime state is rooted at `~/.ruflo`.
- Detect and report project-local Ruflo state paths:
  - `.ruflo`
  - `.claude-flow`
  - `.swarm`
  - `agentdb.rvf`
  - `agentdb.rvf.lock`
  - `ruvector.db`
- Do not move or delete active runtime databases automatically.

### Caveman

- Install and configure using the repo-documented method.
- Keep scoped to conversational and log compression.
- Never compress code, file paths, exact CLI commands, API names, flags, errors,
  or exact command output.

### Superpowers

- Install and configure using the repo-documented method.
- Update repo guidance so Superpowers is manual-only in a session.
- Do not auto-invoke Superpowers for software development work unless the user
  explicitly requests it.

## Logging

Default log path:

```text
~/.agents/install.log
```

Log entries should include:

- timestamp
- step name
- selected targets
- derived instruction-file tool set
- prerequisite checks
- command start and end
- command failure
- Context7 credential stop message
- Ruflo runtime path checks
- stack tool configuration selections
- dry-run status
- secrets-redacted command text

The terminal output should show the same high-level step sequence without
dumping noisy command output unless a command fails.

## Error Handling

Missing selected target prerequisite:

- stop before changes
- print the failed target
- print prerequisite instructions
- log failure

Missing VS Code CLI for a selected VS Code target:

- stop before changes
- tell the user to install VS Code and enable the `code` shell command
- log failure

Missing Context7 credentials:

- stop before Context7 configuration
- print credential setup instructions
- do not write placeholder credentials
- log failure

Stack tool install failure:

- stop immediately
- preserve prior successful changes
- log failed step and command
- print the log path

Project-local Ruflo state found:

- warn and log paths
- do not delete or move active DBs
- continue only when `~/.ruflo` configuration can still be applied safely
- otherwise stop with remediation instructions

## Proposed Script Structure

Keep the repo Bash-only and aligned with existing shell patterns.

- `scripts/bootstrap.sh`
  - one-command remote entry point
  - temporary payload download
  - checksum verification when supplied
  - argument forwarding
  - cleanup

- `scripts/install.sh`
  - CLI parsing
  - interactive prompts
  - target normalization
  - logging setup
  - high-level flow

- `scripts/lib/targets.sh`
  - parse `--targets`
  - validate target names
  - derive `codex|claude|both`

- `scripts/lib/preflight.sh`
  - verify selected AI clients
  - verify VS Code `code` CLI for selected VS Code targets
  - enforce no-change preflight boundary

- `scripts/lib/logging.sh`
  - step output
  - log writes
  - redaction helpers

- `scripts/lib/stack-tools.sh`
  - install and configure LeanCTX, Context7, Ruflo, Caveman, and Superpowers
  - use repo-documented recommendations

- `scripts/lib/ruflo-state.sh`
  - enforce `~/.ruflo` preference
  - detect project-local Ruflo state
  - report remediation without deleting active DBs

Existing files remain in use:

- `scripts/seed-project-instructions.sh`
- `templates/*.md`
- managed Git hook behavior

## Documentation Updates

Update README:

- Present one-command install first.
- Document `--targets`.
- Explain target prerequisites.
- Explain Context7 credential stop behavior.
- Move clone-based instructions to development usage.
- State that selected AI clients and VS Code are prerequisites.
- State that stack tools are installed and configured by this installer.

Update Codex stack setup docs:

- Add Context7 setup.
- Keep LeanCTX and Ruflo ownership boundaries clear.
- Keep Ruflo state under `~/.ruflo`.
- Make Superpowers manual-only.

Update Claude stack setup docs:

- Add Context7 setup.
- Keep LeanCTX and Ruflo ownership boundaries clear.
- Keep Ruflo state under `~/.ruflo`.
- Make Superpowers manual-only.

Update templates as needed so generated global instruction files match the new
manual-only Superpowers policy and Context7 guidance.

## Tests

Add or update shell tests for:

- valid `--targets` parsing
- invalid target rejection
- interactive surface selection
- non-interactive target selection
- deriving `--tools` from selected targets
- backward compatibility for current `--tools` flows
- stop-before-change behavior for missing Codex prerequisite
- stop-before-change behavior for missing Claude prerequisite
- stop-before-change behavior for missing VS Code `code` CLI
- missing Context7 credentials stop path
- visible step output
- log file contents
- secret redaction in logs
- Ruflo project-local state warning
- one-command bootstrap argument forwarding

Verification after implementation:

```bash
bash -n scripts/*.sh tests/*.sh
for test in tests/*.sh; do bash "$test"; done
git diff --check
```

## Open Decisions

No open product decisions remain. Implementation should verify exact current
install commands from upstream documentation before wiring them into the repo
recommendation docs and installer.
