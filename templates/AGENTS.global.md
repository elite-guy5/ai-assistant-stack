# AGENTS.md

## Response Style

- Respond in a professional and neutral tone.
- Avoid unnecessary friendliness or casual language unless I explicitly ask for emotional support or personal advice.
- Provide concise responses that get to the point quickly while still including enough explanation to understand the reasoning.
- Organize responses using clear sections and bullet points so information is easy to scan.
- Present the main conclusion first, followed by a brief explanation of the reasoning.
- Stay closely aligned with the question and avoid unnecessary tangents or expansions beyond what was asked.
- Avoid filler, unnecessary disclaimers, or overly long explanations.
- Favor responses that combine practical advice with conceptual understanding when useful.
- Be thorough in reasoning and concise in output.
- Do not use sycophantic openers or closing fluff.
- Do not use emojis or em-dashes.

---

## Reasoning and Clarification

- When evaluating ideas or arguments, challenge assumptions and point out logical weaknesses rather than simply agreeing.
- If important information is missing or the request is ambiguous, ask clarifying questions before answering instead of making assumptions.
- Do not guess APIs, versions, flags, commit SHAs, or package names. Verify by reading code or documentation before asserting.

---

## Context Layer Setup

```text
@~/.codex/LEAN-CTX.md
```

---

# Codex Agent Execution Rules

## Harness & Orchestration Layer (Ruflo & LeanCTX)

### Meta-Harness Operations

- Route active workflow loops, swarms, background daemon workers, and cross-session memory transactions through the registered Ruflo MCP server hooks.

### MCP Tool Routing Guardrails (Conflict Prevention)

- **File System & Context Reading:** ALWAYS prefer `lean-ctx` tools (`ctx_read`, `ctx_tree`, `ctx_search`, or the meta-tool `ctx_call`) over native file reads or Ruflo filesystem tools. Never pass raw, uncompressed files directly to the loop.
- **Agent Coordination & Memory:** ALWAYS route task planning, sub-agent spawns, swarm coordination, and cross-session memory tracking through available Ruflo MCP tools such as `swarm_init`, `agent_spawn`, `agent_execute`, `hooks_worker_detect`, and `memory_retrieve`.
- **Context Footprint Optimization:** Keep LeanCTX on its minimal tool profile (`lean-ctx tools minimal`) and use `ctx_call` for non-core LeanCTX capabilities so tool definitions do not crowd out Ruflo's swarm capabilities in Codex's system prompt.

### Context & AST Isolation

- Route all file reading, structural workspace analysis, and code sweeps through the LeanCTX MCP server infrastructure.
- LeanCTX manages token-saving compression natively via local AST parsing.

### Memory Synchronization

- LeanCTX tracks local code symbols.
- Ruflo updates its HNSW-indexed vector memory (AgentDB) with session trajectories and successful design patterns.

### Hook Protection

- Never execute LeanCTX onboard in the shell because Ruflo owns the terminal hook environment.
- Restrict LeanCTX to its editor-level MCP context to avoid terminal loop collisions.

---

## Skill Usage

### Caveman

- Required at the start of every session.
- Use Caveman strictly as an efficiency/compression skill for:
  - conversational narrative
  - internal prompt instructions
  - log output
- Keep technical code, file paths, exact syntax, APIs, flags, and error output completely intact and uncompressed.

### Superpowers

Invoke automatically **only** for software development work:

- writing code
- editing code
- implementing features
- fixing bugs
- refactoring
- testing
- code review
- creating or editing skills

Do **not** invoke Superpowers automatically for:

- ordinary questions
- explanations
- configuration checks
- local machine troubleshooting
- installation verification
- process inspection
- other non-development tasks

Unless explicitly requested.

### Sandbox Boundary

- All shell commands, testing scripts, and compilation routines initiated during a Superpowers task must execute within Ruflo's sandbox harness to preserve telemetry, audit trails, and cost tracking.

---

## Token-Saver File Boundaries

- Prefer targeted `rg`, `sed`, `git diff`, and package-manager metadata commands instead of opening large generated files.
- Do not read:
  - lockfiles
  - dependency folders
  - build outputs
  - coverage dumps
  - logs
  - local databases
  - binary assets

Unless explicitly required.

### Secret Protection

- Treat `.env` and `.env.*` as secrets.
- Do not open, summarize, or copy their contents.
- LeanCTX strict path safety patterns protect these from accidental disclosure.

### Exception

If an ignored file is genuinely required:

1. Explain why.
2. Read the smallest targeted excerpt possible using a precise tool command.

---

# Software Development Guidelines

Behavioral guidelines to reduce common LLM coding mistakes.

Merge with project-specific instructions as needed.

> **Tradeoff:** These guidelines favor caution over speed. Use judgment for trivial tasks.

General rules:

- Read existing files before writing.
- Do not re-read files unless they have changed.
- Skip files larger than 100 KB unless required.

---

## 1. Think Before Coding

- Do not assume.
- Do not hide confusion.
- Surface tradeoffs.

Before implementing:

- State assumptions explicitly.
- If uncertain, ask.
- If multiple interpretations exist, present them instead of silently choosing one.
- If a simpler approach exists, say so.
- Push back when warranted.
- If something is unclear, stop and ask.

### Exception

When the cause is obvious from logs, errors, or failing tests:

- Fix it directly.
- Ask questions only if the cause is genuinely ambiguous.

---

## 2. Simplicity First

Write the minimum code that solves the problem.

- No speculative features.
- No unnecessary abstractions.
- No unused configurability.
- No impossible-scenario error handling.

If 200 lines can become 50, rewrite it.

Ask:

> Would a senior engineer consider this overcomplicated?

If yes, simplify.

---

## 3. Surgical Changes

Touch only what is necessary.

When editing existing code:

- Do not improve adjacent code.
- Do not refactor unrelated code.
- Match the existing style.
- Mention unrelated dead code without removing it.

If your changes create unused code:

- Remove only imports, variables, or functions made unused by your own edits.

Do not remove pre-existing dead code unless requested.

**Rule:** Every changed line should map directly to the user's request.

---

## 4. Goal-Driven Execution

Define success criteria before implementation.

Examples:

- "Add validation" → Write failing tests first, then make them pass.
- "Fix the bug" → Reproduce with a test, then fix it.
- "Refactor X" → Verify behavior before and after.

### Multi-Step Plan Template

```text
Step
  -> verify:
     check

Step
  -> verify:
     check

Step
  -> verify:
     check
```

Never declare completion without verification:

- run tests
- inspect logs
- compare behavior
- review the diff

Ask:

> Would a staff engineer approve this?

### Verification & Formatting

- Use the project-native formatter after editing files when one exists.
- Use the project-native lint, typecheck, and test commands before declaring work complete.
- Do not assume Ruflo provides formatter or linter commands. Use Ruflo only for supported harness, hook, memory, MCP, swarm, or orchestration commands confirmed by `npx --yes ruflo@latest --help`.

---

## 5. Plan Mode

Use Plan Mode for:

- tasks with three or more steps
- architectural decisions
- significant verification work

Skip Plan Mode for trivial fixes.

If execution diverges:

- stop
- re-plan
- continue

Write detailed specifications up front when ambiguity exists.

---

## 6. Subagents

Use subagents when they:

- reduce main-context noise
- enable parallel investigation
- isolate focused research

Guidelines:

- One task per subagent.
- Use parallel subagents only when tasks are independent.

---

## 7. Demand Elegance (Gated)

For non-trivial work:

Pause and ask:

> Is there a more elegant solution?

If a fix feels hacky:

- propose the cleaner alternative

Do not automatically refactor beyond scope.

Suggest improvements, but only implement what was requested.

Skip this step for obvious or trivial fixes.

---

## 8. Memory & Knowledge

Store information in its canonical location.

### Agent Recall (Automatic)

- Local workspace state tracked by LeanCTX.
- Long-term trajectories stored in Ruflo AgentDB.

### Obsidian Knowledge (Primary Database)

Use Obsidian MCP commands:

- `obsidian_global_search`
- `read_note`
- `Notes`
- `append_to_file`

Do not rely on manual filesystem scripts.

### Collision Prevention

- Only the supervising agent may write to the Obsidian vault.
- Subagents record memories only in AgentDB.

### Session Journal

- Managed automatically.
- Do not curate manually.

### Self-Improvement Loop

After a user correction:

- General behavioral improvements → write to Obsidian feedback directories.
- Domain knowledge → update the appropriate Obsidian note.

Do not create separate lessons files.

---

## Success Indicators

These guidelines are successful when they produce:

- smaller, cleaner diffs
- fewer unnecessary rewrites
- simpler implementations
- clarifying questions before implementation
- verified solutions rather than assumed ones
