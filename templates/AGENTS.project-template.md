# <Project Name>

Project-specific instructions. Inherits global behavior from `~/.codex/AGENTS.md`.

## Project Info
- **Purpose:** <one line>
- **Language / Framework:** <fill>
- **Key entry points:** <paths>

## Commands
- Build:   <cmd>
- Test:    <cmd>
- Lint:    <cmd>
- Run:     <cmd>

## Conventions
- <repo-specific style, patterns, dirs the global rules don't cover>
- <repo-specific gotchas - keep them here, not in global memory>

## Token-Saver File Boundaries

- Keep generated files, secrets, logs, coverage, dependency folders, local databases, and binary assets out of agent context by default.
- Project seeding maintains `.gitignore`, `.codexignore`, and `.claude/settings.local.json` with common token-bloat exclusions.
- If this repo needs narrower or broader exclusions, update the local ignore files rather than weakening the global behavior.

## Development Workflow

This repo also inherits the global required-session rule to load/use the Caveman skill at the start of every Codex session. Caveman does not override project-specific response style or development workflow rules.

This repo defers to the **Superpowers** workflow when relevant to software development work. Default process, in order:

1. **brainstorming** - refine the idea, get design sign-off.
   Spec saved to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.
2. **writing-plans** - bite-sized tasks with exact file paths + tests.
   Plan saved to `docs/superpowers/plans/YYYY-MM-DD-<feature>.md`.
3. **using-git-worktrees** - isolated branch + clean test baseline.
4. **subagent-driven-development** / **executing-plans** - work the plan task by task
   with review checkpoints.
5. **test-driven-development** - ENFORCED default for this repo. Red-green-refactor:
   write the failing test first, watch it fail, then minimal code.
6. **requesting-code-review** -> **finishing-a-development-branch** - review, then
   merge / PR / cleanup.

**Precedence:** instructions in THIS file override skills where they conflict
(user AGENTS.md > skills). Put any project-specific deltas under Conventions.

Durable learnings go to memory (global section 8: native `feedback` memory, or the
Obsidian vault for domain knowledge), not here.
