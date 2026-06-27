# macOS Instruction-File Manager Implementation Plan

**Goal:** Keep only macOS Bash installation for Codex and Claude Code
instruction files plus Git hook automation.

**Architecture:** Replace the broad installer with a small Bash script,
a shell-only seeder, Git template hooks, and shell tests that run in temporary
homes and repositories.

**Tech Stack:** Bash, Git, Markdown templates, shell regression tests.

## Tasks

- Replace installer CLI with `--tools`, `--repo`, dry-run, overwrite, and
  uninstall flags.
- Install only selected global files, selected templates, the shared seeder,
  and managed Git template hooks.
- Seed only `AGENTS.md`, `CLAUDE.md`, or both based on selected tools.
- Delete non-macOS, session-start, ignore-optimizer, and third-party
  automation files.
- Rewrite user and agent documentation around the new macOS-only scope.
- Verify with shell syntax checks, regression tests, removed-surface scan, and
  `git diff --check`.
