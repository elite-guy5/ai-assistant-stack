# Project Rules & Commands

> Inherits behavioral, tool, and operational architecture guidelines from `~/.claude/CLAUDE.md`.

## Project Info

### Purpose
- `<One-line description of the project's core utility, service, or objective>`

### Language / Framework
- `<Primary languages, frameworks, runtimes, and data stores>`

### Key Entry Points
- `<Critical source files, configuration files, routing manifests, or scripts>`

---

## Development Commands

| Task | Command |
|------|---------|
| **Build** | `<Build command, or "No compiled build">` |
| **Test** | `<Command to run unit, integration, or smoke tests>` |
| **Format** | `<Project-native formatter command, or "No formatter configured">` |
| **Lint / Typecheck** | `<Project-native lint, syntax, or typecheck command>` |
| **Run** | `<Command to run the project locally, including host and port when applicable>` |

---

## Verification Requirements

Execute these steps in addition to the global verification and formatting workflows specified in `~/.claude/CLAUDE.md`:

1. Run the project-native formatter for all changed files, if one exists.
2. Run the project-native lint, syntax, or typecheck command.
3. Run relevant project-level tests to validate functionality.

---

## Conventions

### Testing
- `<Test locations, framework, naming conventions, and coverage expectations>`

### Coding Standards
- `<Project-specific style, architecture, import rules, and directory layout>`

### Project-Specific Rules
- `<Business rules, workflow requirements, or repository-specific guidance>`

---

## Context Boundaries

- Maintain project-specific file exclusions exclusively through repository ignore files (`.gitignore`) to keep runtime evaluations clean.
- Rely on the global token-saver boundaries for standard artifact, dependency, log, database, and secret exclusions.