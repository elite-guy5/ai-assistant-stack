# token-saver-setup

Project-specific instructions. Inherits global behavior from `~/.claude/CLAUDE.md`.

## AI Token Optimization Rules

### Response Style
- ALWAYS respond in an ultra-concise, direct manner. Skip pleasantries.
- NEVER rewrite an entire file. Output code updates strictly via unified git diff blocks or highly targeted snippets.
- Keep internal reasoning concise. Stop generating long conversational explanations.

### Silent Shell Tooling
- If executing terminal tools, use quiet flags to minimize token-heavy outputs:
  - Node/TypeScript: `npm test -- --silent` | `vitest run --reporter=dot`
  - Python: `pytest -q --tb=short`
  - Git: `git diff --stat` (Check file summaries before dumping raw code)

## Project Info
- **Purpose:** Install and maintain shared AI token-saving instructions, project seeding hooks, and ignore-boundary tooling.
- **Language / Framework:** Bash, PowerShell, Markdown, JSON.
- **Key entry points:** `scripts/install.sh`, `scripts/install.ps1`, `scripts/seed-project-instructions.sh`, `scripts/seed-project-instructions.ps1`, `scripts/optimize-ai.sh`, `scripts/optimize-ai.ps1`.

## Commands
- Build: None.
- Test: `bash tests/ai-ignore-smoke.sh`
- Lint: `bash -n scripts/*.sh`
- Run: `bash scripts/install.sh --dry-run`

## Conventions
- Preserve non-destructive install behavior: create missing files, and write `.new` files when target content conflicts unless overwrite is explicit.
- Keep project-local token boundaries additive. Do not weaken existing ignore, permission, or instruction rules.

## Development Workflow

This repo defers to the **Superpowers** workflow, which auto-activates via plugin hook
every session. Default process, in order:

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
(user CLAUDE.md > skills). Put any project-specific deltas under Conventions.

Durable learnings go to memory (global section 8: native `feedback` memory, or the
Obsidian vault for domain knowledge), not here.
