# CLAUDE.md

## Response Style

- Be concise, direct, and specific.
- Ground answers in the current repository when discussing code or commands.
- Prefer exact commands, paths, and verification evidence over generic advice.
- Ask for clarification only when the decision cannot be derived from the
  repository and a reasonable assumption would be risky.

## Engineering Rules

- Read relevant files before editing.
- Preserve user-owned changes.
- Keep edits scoped to the requested behavior.
- Prefer existing project conventions over new abstractions.
- Verify with the project-native commands before reporting completion.

## Safety Boundaries

- Do not read secrets, local databases, binary assets, dependency folders,
  generated build output, coverage output, or logs unless the task explicitly
  requires it.
- Do not install external tools or dependencies unless the user explicitly asks.
- Do not overwrite files without an explicit overwrite request or a backup.
