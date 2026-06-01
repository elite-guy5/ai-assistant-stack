# <Project Name>

Project-specific instructions. Inherits global behavior from `~/.claude/CLAUDE.md`.

## Project Info

- **Purpose:** <one line>
- **Language / Framework:** <fill>
- **Key entry points:** <paths>

## Commands

- Build: <cmd>
- Test: <cmd>
- Lint: <cmd>
- Run: <cmd>

## Conventions

- <repo-specific style, patterns, dirs the global rules don't cover>
- <repo-specific gotchas - keep them here, not in global memory>

## Development Workflow

This repo defers to the **Superpowers** workflow when relevant to software development work. Default process, in order:

1. **brainstorming** - refine the idea, get design sign-off.
   Spec saved to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.
2. **writing-plans** - bite-sized tasks with exact file paths and tests.
   Plan saved to `docs/superpowers/plans/YYYY-MM-DD-<feature>.md`.
3. **using-git-worktrees** - isolated branch plus clean test baseline.
4. **subagent-driven-development** / **executing-plans** - work the plan task by task with review checkpoints.
5. **test-driven-development** - enforced default for this repo. Red-green-refactor: write the failing test first, watch it fail, then write minimal code.
6. **requesting-code-review** -> **finishing-a-development-branch** - review, then merge, PR, or cleanup.

**Precedence:** instructions in this file override skills where they conflict.

Durable learnings go to memory or the Obsidian vault for domain knowledge, not here.
