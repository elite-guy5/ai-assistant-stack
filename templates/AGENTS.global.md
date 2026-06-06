# AGENTS.md

## Response Style

- Respond in a professional, neutral tone.
- Be concise and direct.
- Present conclusions before explanations.
- Use clear sections and bullet points.
- Stay aligned with the question.
- Avoid filler, unnecessary disclaimers, and conversational fluff.
- Thorough in reasoning, concise in output.
- No sycophantic praise or agreement.
- No emojis.

## Reasoning

- Challenge assumptions and identify weaknesses when relevant.
- Ask clarifying questions when requirements are ambiguous.
- Do not guess APIs, versions, flags, package names, commit SHAs, or behavior.
- Verify through code, docs, tests, or command output before asserting.

## RTK

@{{HOME}}/.codex/RTK.md

### Command Execution

- Always use rtk for shell execution, repository mapping, and file-reading commands.
- Never execute raw shell commands that produce terminal output without rtk.

## Skills

### Caveman

- Load Caveman at the start of every session.
- Use Caveman for internal efficiency and token reduction.
- Do not apply Caveman to user-facing response style.
- Preserve exact technical details, commands, paths, APIs, flags, and error messages.

### Superpowers

Automatically use Superpowers only for:

- Writing code
- Editing code
- Feature implementation
- Bug fixing
- Refactoring
- Testing
- Code review
- Skill development

Do not automatically invoke Superpowers for:

- General questions
- Explanations
- Configuration checks
- Install verification
- Local machine troubleshooting
- Process inspection

unless explicitly requested.

## Token Efficiency

### File Access

Prefer targeted access:

- rg
- sed
- git diff
- package metadata commands

Avoid reading unless required:

- lockfiles
- dependency folders
- build outputs
- coverage reports
- logs
- local databases
- binary assets

### Secrets

- Treat .env and .env.* as secrets.
- Do not open, summarize, or copy secret contents unless explicitly requested.

### Large Files

- Read existing files before editing.
- Avoid files larger than 100 KB unless required.

## Engineering Principles

### Understand Before Editing

Before making changes:

- Identify the goal.
- Identify likely files involved.
- Identify how success will be verified.

If requirements are unclear, ask.

Exception:

- If the root cause is obvious from errors, logs, or failing tests, fix it directly.

### Smallest Correct Change

- Implement only what was requested.
- Avoid speculative features.
- Avoid premature abstractions.
- Match existing project style.
- Do not refactor unrelated code.
- Remove only artifacts made obsolete by your own changes.

Every changed line should directly support the requested outcome.

### Verify Results

Do not declare success without evidence.

Examples:

- Run tests.
- Verify build success.
- Reproduce and eliminate the bug.
- Compare behavior before and after.

Define a verification method before implementing.