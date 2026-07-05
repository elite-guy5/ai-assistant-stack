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
- Do not use emojis or em dashes.

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

## Context Layer

### MCP Tool Routing Guardrails

- **File System & Context Reading:** Prefer `lean-ctx` tools (`ctx_read`, `ctx_tree`, `ctx_search`, or the meta-tool `ctx_call`) over native file reads when those tools are available.
- **Context Footprint Optimization:** Use LeanCTX's stack setup path (`lean-ctx setup` from an active Git project with IDE access enabled, telemetry off, auto-updates on, compression `max`, archive on, return to the user home directory, `lean-ctx config set path_jail false --yes`, and `lean-ctx proxy enable`) unless the user explicitly asks to tune LeanCTX separately, and use `ctx_call` for non-core LeanCTX capabilities when practical.

### Context7

Use Context7 MCP for current documentation when working with libraries,
frameworks, SDKs, APIs, CLIs, and cloud services. Do not use Context7 for
general programming concepts, refactoring from local code, or business logic
debugging.

### Context & AST Isolation

- Route file reading, structural workspace analysis, and code sweeps through the LeanCTX MCP server infrastructure when available.
- LeanCTX manages token-saving compression natively via local AST parsing.

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

Invoke Superpowers manually when a task explicitly requests the workflow or
when an already-active Superpowers workflow requires the next Superpowers skill.
Do not auto-invoke Superpowers just because the task is software development.

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

- "Add validation" -> Write failing tests first, then make them pass.
- "Fix the bug" -> Reproduce with a test, then fix it.
- "Refactor X" -> Verify behavior before and after.

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

## 7. Demand Elegance

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

### Agent Recall

- Local workspace state is tracked by LeanCTX when available.
- Use the active product's native memory tools when durable operational memory is needed.

## 8. Memory & Knowledge

Store information in its canonical location.

### Systemic Context & Agent Recall
- Local workspace state, temporal facts, and session findings are tracked natively by LeanCTX via `ctx_knowledge`.
- Rely on LeanCTX utilities (`ctx_search`, `ctx_read`) to maintain codebase awareness without polluting external files.

### Domain Knowledge
- Keep core domain knowledge, business logic constraints, and local architectural rules in the project's native `/docs` or markdown files. 
- Let LeanCTX index and fetch these files dynamically during the session.

### Human Knowledge Curation (Obsidian Hand-off)
- Do not attempt to automatically write logs, lessons learned, or behavioral updates to external personal notes or Obsidian vaults.
- If a major structural decision, complex bug resolution, or high-leverage architectural paradigm is established, focus entirely on solving the task first. 
- Only generate a structured, clean Markdown summary of these findings if the user explicitly requests a session post-mortem for their personal human curation.

---

## Success Indicators

These guidelines are successful when they produce:

- smaller, cleaner diffs
- fewer unnecessary rewrites
- simpler implementations
- clarifying questions before implementation
- verified solutions rather than assumed ones
