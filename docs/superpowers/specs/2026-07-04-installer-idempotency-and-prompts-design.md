# Installer Idempotency And Replacement Prompts Design

## Goal

Make the installer safer and more accurate for repeated runs:

- Ask interactive users before replacing existing instruction files.
- Keep non-interactive installs skip-by-default unless overwrite flags are explicit.
- Skip Caveman and Superpowers installation when the selected client already has them installed.
- Install Superpowers for Claude Code through Claude Code's native plugin command.

## Current Context

The installer is a Bash-based workflow. `scripts/install.sh` owns instruction-file installation and replacement flags. `scripts/lib/stack-tools.sh` owns LeanCTX, Context7, Caveman, and Superpowers setup. Tests are plain Bash scripts under `tests/`.

Current instruction-file behavior skips existing files unless overwrite flags are passed. Current Caveman and Superpowers setup invokes install commands each run and treats some upstream idempotency errors as success. Current Claude Superpowers setup clones and symlinks `obra/superpowers`, but Claude Code exposes a plugin install path:

```bash
claude plugin install superpowers@claude-plugins-official --scope user
```

## Selected Approach

Use a surgical installer update in the existing Bash boundaries.

Rejected alternatives:

- A central desired-state planner would be cleaner for a larger installer rewrite, but it would add unnecessary scope for these changes.
- Relying only on upstream idempotency would still run installers when the user asked to skip already-installed Caveman and Superpowers.

## Instruction File Replacement

Interactive installs should prompt only when all of these are true:

- The target instruction file already exists.
- No matching overwrite flag was passed.
- The installer is not running in `--non-interactive` mode.

When prompted:

- `yes` backs up the existing file with the current timestamped backup naming, then copies the managed template.
- `no` skips that file and reports a skipped status.

Non-interactive installs keep current behavior:

- Existing files are skipped by default.
- `--overwrite` backs up and replaces all managed instruction targets.
- `--overwrite-global-instructions` applies only to global instruction files.
- `--overwrite-project-templates` applies only to project template files.

The prompt belongs near the existing `install_file` path so global Codex, Codex template, global Claude, and Claude template files share one behavior.

## Stack Tool Idempotency

Add explicit installed-state checks before running Caveman or Superpowers installers.

For Caveman:

- Codex check: run `npx skills list --json --global --agent codex` and look for a skill named `caveman`.
- Claude Code check: run `claude plugin list --json` and look for plugin id `caveman@caveman`.
- If already installed, print a skipped/already-installed status and do not run install commands.

For Superpowers:

- Codex check: run `codex plugin list` and look for installed `superpowers@openai-curated`.
- Codex install: run `codex plugin add superpowers@openai-curated`.
- Claude Code check: run `claude plugin list --json` and look for plugin id `superpowers@claude-plugins-official`.
- Claude Code install: run `claude plugin install superpowers@claude-plugins-official --scope user`.
- If already installed, print a skipped/already-installed status and do not run install commands.

If a selected client is missing, keep the current skip behavior. If a selected client is present but its list command fails, fail clearly instead of blindly installing over unknown state.

## Components

`scripts/install.sh`:

- Extend instruction-file installation so interactive replacement prompts are handled consistently.
- Preserve existing overwrite flags and backup behavior.

`scripts/lib/stack-tools.sh`:

- Add small helpers for installed-state checks.
- Keep `run_stack_command` for actual install commands, dry-run behavior, logging, redaction, and upstream idempotency fallback.
- Replace Claude Superpowers clone/symlink setup with the native Claude plugin install command.

Tests:

- Add focused coverage in existing shell test files or a new narrow test file if that keeps assertions clearer.
- Stub `npx`, `codex`, and `claude` where needed so tests do not mutate the real machine.

## Error Handling

- Missing selected CLI: skipped status, matching current behavior.
- Failed installed-state command for available CLI: installer exits with a clear failure.
- Invalid JSON from a list command: installer exits with a clear failure instead of guessing.
- Dry run: report planned checks and installs without mutating files or client state.

## Testing And Verification

Required verification:

```bash
bash -n scripts/*.sh tests/*.sh
```

Run focused tests for:

- Interactive replacement prompt on existing instruction files.
- Non-interactive existing-file skip behavior.
- Existing overwrite flags replacing files without prompting.
- Caveman skip behavior for Codex and Claude Code.
- Superpowers skip behavior for Codex and Claude Code.
- Claude Superpowers install command:

```bash
claude plugin install superpowers@claude-plugins-official --scope user
```

Then run the full regression suite:

```bash
for test in tests/*.sh; do bash "$test"; done
```

Finally, review the diff for scope and accidental churn.
