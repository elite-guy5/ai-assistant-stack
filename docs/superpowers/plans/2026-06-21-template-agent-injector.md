# Template Agent Injector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce the installer to global instruction files, project templates, project seeding scripts, Claude `SessionStart` hook wiring, and uninstall support for those retained artifacts.

**Architecture:** Keep both remote bootstrappers as thin download-and-dispatch entry points. Replace the broad Shell and PowerShell installer flows with matching retained-component flows, while preserving overwrite controls, bounded project scope, manifest ownership, dry-run output, and user-file protection. Keep seeding scripts focused on creating missing project-local instruction files from installed templates.

**Tech Stack:** Bash, PowerShell, JSON edited through Node/PowerShell structured APIs, Markdown templates, shell regression tests

---

## File Structure

- Modify `scripts/install.sh`: retained CLI parsing, install flow, manifest records, SessionStart wiring, and scoped uninstall.
- Modify `scripts/install.ps1`: PowerShell-equivalent retained CLI and behavior.
- Modify `scripts/seed-project-instructions.sh`: remove optimizer/ignore-boundary work while retaining bounded template injection.
- Modify `scripts/seed-project-instructions.ps1`: PowerShell parity for template injection.
- Modify `tests/install-dry-run.sh`: assert retained dry-run behavior and removed CLI surface.
- Modify `tests/install-uninstall-prompt.sh`: assert retained uninstall selection and ownership protection.
- Modify `tests/install-visible-output.sh`: replace removed-tool visibility cases with retained installer progress/error visibility.
- Delete `tests/ai-ignore-smoke.sh`: subsystem removed.
- Delete `tests/rtk-claude-hook.sh`: subsystem removed.
- Modify `tests/security-regression.sh`: retain pinned-download, path, JSON, and user-owned-file checks; remove subsystem-specific checks.
- Modify `README.md`: document only retained installation, flags, artifacts, seeding, and uninstall behavior.
- Keep `scripts/bootstrap.sh`, `scripts/bootstrap.ps1`, `config/claude-settings-sessionstart.json`, `config/claude-settings-sessionstart.windows.json`, and template files unchanged unless a test proves parity requires a narrow correction.

### Task 1: Lock Retained and Removed Behavior in Tests

**Files:**
- Modify: `tests/install-dry-run.sh`
- Modify: `tests/install-uninstall-prompt.sh`
- Modify: `tests/install-visible-output.sh`
- Modify: `tests/security-regression.sh`

- [ ] **Step 1: Add failing retained-surface assertions**

Add test cases that run installers with temporary `HOME` and `PROJECT_SCOPE`, then assert:

```bash
assert_contains "$output" "$HOME/.claude/CLAUDE.md"
assert_contains "$output" "$HOME/.codex/AGENTS.md"
assert_contains "$output" "$HOME/.claude/CLAUDE.project-template.md"
assert_contains "$output" "$HOME/.codex/AGENTS.project-template.md"
assert_contains "$output" "$HOME/.agents/scripts/seed-project-instructions.sh"
assert_contains "$output" "SessionStart"
assert_not_contains "$output" "RTK"
assert_not_contains "$output" "Caveman"
assert_not_contains "$output" "AI ignore"
```

Add invalid-flag checks for one removed flag per subsystem:

```bash
assert_command_fails bash "$ROOT/scripts/install.sh" --skip-rtk
assert_command_fails bash "$ROOT/scripts/install.sh" --skip-caveman
assert_command_fails bash "$ROOT/scripts/install.sh" --ai-apps claude
```

For PowerShell, inspect help/parameter declarations when `pwsh` is unavailable; otherwise run equivalent invalid-parameter cases.

- [ ] **Step 2: Add failing install and uninstall ownership tests**

Create temporary pre-existing global files and templates, run install without overwrite, and assert their exact contents remain. Run with `--overwrite-global-instructions` and `--overwrite-project-templates`, then assert rendered template content exists. Seed a manifest containing retained and obsolete component entries, uninstall `all available`, and assert only retained installer-created files and the matching SessionStart entry are removed.

- [ ] **Step 3: Run tests to verify current implementation fails the new contract**

Run:

```bash
bash tests/install-dry-run.sh
bash tests/install-uninstall-prompt.sh
bash tests/install-visible-output.sh
bash tests/security-regression.sh
```

Expected: at least removed-surface assertions fail because current installers still expose RTK, Caveman, and AI-ignore behavior.

- [ ] **Step 4: Commit test contract**

```bash
git add tests/install-dry-run.sh tests/install-uninstall-prompt.sh tests/install-visible-output.sh tests/security-regression.sh
git commit -m "test: define focused injector behavior"
```

### Task 2: Reduce Bash Installer and Seeder

**Files:**
- Modify: `scripts/install.sh`
- Modify: `scripts/seed-project-instructions.sh`

- [ ] **Step 1: Replace Bash CLI surface with retained flags**

Keep parsing for:

```text
--non-interactive
--dry-run
--overwrite
--overwrite-global-instructions
--overwrite-project-templates
--project-scope <path>
--uninstall
--uninstall-components <list>
--help
```

Restrict uninstall components to:

```text
global-instructions, reset-global-instructions, project-instructions, project-templates, seeding
```

Unknown removed flags must use existing unknown-option handling and exit `2`.

- [ ] **Step 2: Remove removed subsystem functions and state**

Delete RTK install/init/verify/uninstall, Caveman install/config/fallback/uninstall, AI-ignore optimizer install/uninstall, AI-app/asset normalization, removed prompts, tool report rows, and obsolete download-verification state. Preserve generic file copy, rendering, manifest, JSON hook, report, and safety helpers used by retained paths.

- [ ] **Step 3: Make install flow invoke only retained operations**

Install in this order:

```text
1. Render global Claude and Codex instruction files.
2. Render Claude and Codex project templates.
3. Render/install seed-project-instructions.sh and seed-project-instructions.ps1.
4. Ensure exactly one managed Claude SessionStart hook entry.
5. Run bounded project seeding for first-level projects under PROJECT_SCOPE.
6. Write retained manifest entries and install report.
```

Maintain existing skip-by-default behavior for user-owned global/template files and existing overwrite flags.

- [ ] **Step 4: Limit seeder to template injection**

In `scripts/seed-project-instructions.sh`, retain scope validation, first-level project enumeration, placeholder rendering, and create-if-missing behavior for project-local `CLAUDE.md` and `AGENTS.md`. Remove optimizer invocation and creation/modification of `.gitignore`, `.codexignore`, `.claudeignore`, or `.claude/settings.local.json`.

- [ ] **Step 5: Limit uninstall to retained artifacts**

Use retained manifest entries when present. Legacy fallback may inspect/remove only global instruction files, project templates, seeding scripts, matching SessionStart hook entries, and managed sections in project-local instruction files. Never process obsolete manifest component entries.

- [ ] **Step 6: Run Bash tests**

```bash
bash -n scripts/install.sh scripts/seed-project-instructions.sh
bash tests/install-dry-run.sh
bash tests/install-uninstall-prompt.sh
bash tests/install-visible-output.sh
bash tests/security-regression.sh
```

Expected: syntax checks and retained Bash cases pass; PowerShell static parity assertions may still fail until Task 3.

- [ ] **Step 7: Commit Bash reduction**

```bash
git add scripts/install.sh scripts/seed-project-instructions.sh
git commit -m "refactor: focus bash installer on injection"
```

### Task 3: Apply PowerShell Parity

**Files:**
- Modify: `scripts/install.ps1`
- Modify: `scripts/seed-project-instructions.ps1`

- [ ] **Step 1: Reduce PowerShell parameters and component validation**

Keep only PowerShell equivalents:

```powershell
[switch]$NonInteractive
[switch]$DryRun
[switch]$Overwrite
[switch]$OverwriteGlobalInstructions
[switch]$OverwriteProjectTemplates
[string]$ProjectScope
[switch]$Uninstall
[string]$UninstallComponents
```

Validate uninstall values against `global-instructions`, `reset-global-instructions`, `project-instructions`, `project-templates`, and `seeding`, plus `all available`.

- [ ] **Step 2: Remove PowerShell removed-subsystem code**

Delete RTK, Caveman, optimizer, AI-app/asset, unverified-download, and subsystem-specific prompt/report functions and calls. Keep structured JSON updates in `Ensure-ClaudeSessionHook`, manifest ownership tracking, rendering, and retained install/uninstall reporting.

- [ ] **Step 3: Match retained install and seeding order**

Mirror Task 2 install order and protections. In `scripts/seed-project-instructions.ps1`, retain only bounded first-level project discovery and create-if-missing `CLAUDE.md`/`AGENTS.md` injection; remove all ignore-boundary and optimizer behavior.

- [ ] **Step 4: Verify PowerShell syntax and parity**

Run when PowerShell is installed:

```bash
pwsh -NoProfile -Command '$null = [System.Management.Automation.Language.Parser]::ParseFile("scripts/install.ps1", [ref]$null, [ref]$errors); if ($errors.Count) { $errors; exit 1 }'
pwsh -NoProfile -Command '$null = [System.Management.Automation.Language.Parser]::ParseFile("scripts/seed-project-instructions.ps1", [ref]$null, [ref]$errors); if ($errors.Count) { $errors; exit 1 }'
pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/install.ps1 -DryRun -NonInteractive
```

Expected: parser exits `0`; dry run reports only retained files and SessionStart wiring. If `pwsh` is absent, record that limitation and rely on static parity tests.

- [ ] **Step 5: Run regression tests**

```bash
bash tests/install-dry-run.sh
bash tests/install-uninstall-prompt.sh
bash tests/install-visible-output.sh
bash tests/security-regression.sh
```

Expected: all pass.

- [ ] **Step 6: Commit PowerShell reduction**

```bash
git add scripts/install.ps1 scripts/seed-project-instructions.ps1
git commit -m "refactor: focus powershell installer on injection"
```

### Task 4: Remove Obsolete Tests and Rewrite Documentation

**Files:**
- Delete: `tests/ai-ignore-smoke.sh`
- Delete: `tests/rtk-claude-hook.sh`
- Modify: `README.md`

- [ ] **Step 1: Delete subsystem-only tests**

Remove `tests/ai-ignore-smoke.sh` and `tests/rtk-claude-hook.sh`; their subjects no longer exist. Ensure retained security or hook assertions live in the four maintained regression files before deletion.

- [ ] **Step 2: Rewrite README around focused workflow**

Preserve commit-pinned bootstrap URLs. Document:

```text
- global files: ~/.claude/CLAUDE.md and ~/.codex/AGENTS.md
- templates: ~/.claude/CLAUDE.project-template.md and ~/.codex/AGENTS.project-template.md
- seeders: ~/.agents/scripts/seed-project-instructions.sh and .ps1
- Claude SessionStart hook wiring
- first-level PROJECT_SCOPE seeding
- overwrite flags and retained uninstall components
```

Remove all RTK, Caveman, optimizer, ignore-boundary, AI-app, asset, and unverified-download installation instructions and examples.

- [ ] **Step 3: Scan public surface for stale references**

Run:

```bash
rg -n -i 'rtk|caveman|optimize-ai|ai[- ]ignore|ignore-optimizer|skip-rtk|skip-caveman|rtk-agents|rtk-mode|caveman-mode|caveman-args|ai-apps|assets|allow-unverified' README.md scripts tests
```

Expected: no installer/docs/test references remain. References inside global instruction template content are allowed only if they are intentional instructions rather than installation functionality; review each match explicitly.

- [ ] **Step 4: Commit docs and obsolete test removal**

```bash
git add README.md tests/ai-ignore-smoke.sh tests/rtk-claude-hook.sh
git commit -m "docs: describe focused template injector"
```

### Task 5: End-to-End Verification

**Files:**
- Verify: `scripts/bootstrap.sh`
- Verify: `scripts/bootstrap.ps1`
- Verify: `scripts/install.sh`
- Verify: `scripts/install.ps1`
- Verify: `scripts/seed-project-instructions.sh`
- Verify: `scripts/seed-project-instructions.ps1`
- Verify: `README.md`
- Verify: `tests/`

- [ ] **Step 1: Run maintained test suite**

```bash
bash tests/install-dry-run.sh
bash tests/install-uninstall-prompt.sh
bash tests/install-visible-output.sh
bash tests/security-regression.sh
```

Expected: every command exits `0`.

- [ ] **Step 2: Run isolated real install, seed, and uninstall smoke test**

Use temporary `HOME` and `PROJECT_SCOPE`. Verify install creates six retained files plus one SessionStart entry, seeding creates missing project-local `CLAUDE.md` and `AGENTS.md` without overwriting existing files, and uninstall removes installer-owned retained artifacts while preserving pre-existing files.

- [ ] **Step 3: Verify repository scope**

```bash
git status --short
git diff --check
git diff --stat
```

Expected: only approved spec/plan, installer, seeder, test, and README changes; no whitespace errors.

- [ ] **Step 4: Review acceptance criteria**

Confirm every item in `docs/superpowers/specs/2026-06-21-template-agent-injector-design.md` has passing evidence: removed public subsystems, retained global install/templates/seeding/hook, scoped uninstall, Shell/PowerShell parity, and updated tests.

- [ ] **Step 5: Commit verification fixes if needed**

```bash
git add README.md scripts tests docs/superpowers
git commit -m "test: verify focused injector workflow"
```

Skip this commit when verification requires no changes.
