# Command Line Install UX Design

## Goal

Improve the interactive command line install experience without changing the
non-interactive install contract.

The target-selection prompt should feel easier to operate, the installer output
should be easier to scan, and the shell code should include useful comments
around the non-obvious terminal behavior.

## Scope

In scope:

- Replace the interactive target-selection prompt with a Bash-only keyboard UI.
- Remove the interactive `All` target option.
- Start interactive target selection with no targets selected.
- Keep existing yes/no prompts as plain yes/no prompts.
- Improve stdout readability with concise phase-based progress output.
- Keep command details in the existing redacted install log.
- Add comments around raw terminal mode, key parsing, redraw logic, fallback
  behavior, and phase-output helpers.
- Add or update shell tests for the changed prompt and output behavior.

Out of scope:

- New external TUI dependencies such as `gum` or `fzf`.
- Changes to `--targets`, `--tools`, or other non-interactive flags.
- Changes to installer scope, installed tools, prerequisites, or hook behavior.
- Replacing the existing yes/no prompt flow.

## Interaction Design

Interactive target selection replaces only the current numbered target prompt.

Initial state:

```text
Token Saver Setup

Select targets to configure:

> ○ Codex Desktop
  ○ Codex VS Code
  ○ Claude Desktop
  ○ Claude VS Code

Space toggles, Enter confirms, ↑/↓ or j/k moves.
```

Controls:

- Up/down arrows move the focused row.
- `j` and `k` also move focus for terminals where arrow input is awkward.
- Space toggles the focused target.
- Enter confirms the selected targets.
- Enter with no selected targets shows an inline error and keeps the selector
  open.

Selected state:

- Unselected rows use an empty circle: `○`.
- Selected rows use a filled green circle: `●`.
- Toggling a row briefly flashes the filled state so Space has visible feedback.
- Green is emitted with ANSI color only when stdout is a TTY. Non-TTY output
  uses the same `●` character without color so tests and redirected output stay
  stable.

The selected targets continue to normalize to the existing canonical values:

- `codex-desktop`
- `codex-vscode`
- `claude-desktop`
- `claude-vscode`

## Output Design

The installer should print concise progress information on stdout and keep full
command details in `~/.agents/install.log`.

Stdout should be organized by phases:

```text
Token Saver Setup

Selected targets
  OK Codex Desktop
  OK Codex VS Code

Preflight
  OK codex found
  OK code found

Stack tools
  OK LeanCTX already installed
  Dry run Configure Context7

Instruction files
  OK Installed ~/.codex/AGENTS.md
  Skipped Existing ~/.codex/AGENTS.project-template.md

Git hooks
  OK Installed template hooks

Summary
  OK Install complete
  Log ~/.agents/install.log
```

Status labels:

- `OK` for completed or already-satisfied actions.
- `Skipped` for intentionally preserved existing files.
- `Warning` for non-fatal issues such as project-local runtime state paths.
- `Dry run` for actions that would run in a real install.

Errors remain explicit on stderr and include:

- the failing target or phase,
- the missing prerequisite or failing requirement,
- the statement that no files or configuration were changed when applicable,
- the log path.

## Implementation Boundaries

Keep the implementation Bash-only.

Recommended file ownership:

- `scripts/lib/targets.sh`
  - target option data,
  - selector state,
  - redraw logic,
  - raw key parsing,
  - no-selection validation,
  - fallback behavior.
- `scripts/lib/logging.sh`
  - phase headers,
  - status-line helpers,
  - readable dry-run/status formatting,
  - log path summary helper.
- `scripts/install.sh`
  - orchestration only: parse flags, call target selection, run install phases.

TTY behavior:

- Interactive mode should read keyboard input from `/dev/tty` when available.
- Piped bootstrap installs should still prompt through `/dev/tty` when possible.
- If no usable TTY is available, fail clearly and tell the user to rerun with
  `--targets`.
- Non-interactive mode remains unchanged: `--targets` or `--tools` is required.

Comments should explain terminal behavior and state transitions, not restate
obvious assignments.

## Testing

Add or update shell tests for:

- interactive target selection starts with no selected targets,
- no `All` option appears in interactive target selection,
- Enter with no selected target does not continue,
- selected targets normalize to existing canonical target strings,
- non-interactive `--targets` behavior remains unchanged,
- visible output contains concise phase and status lines,
- errors still include clear failure context and log path.

Verification commands:

```bash
bash -n scripts/*.sh tests/*.sh
for test in tests/*.sh; do bash "$test"; done
git diff --check
```

## Acceptance Criteria

- The interactive target selector is keyboard-operable with Space and Enter.
- Selected rows show a green filled-circle state.
- No targets are selected by default.
- `All` is removed from the interactive selector.
- Existing non-interactive installs continue to work.
- Installer stdout is easier to scan than the current plain `Step:` output.
- Full command detail remains available in the redacted install log.
- Comments make the terminal UI code understandable without adding noise to
  straightforward shell logic.
