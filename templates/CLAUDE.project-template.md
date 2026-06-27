# Project CLAUDE.md

> Project-specific instructions. Inherits global behavior from `~/.claude/CLAUDE.md`.

## Project Info

### Purpose

> `<One-line description of the project's core utility, service, or objective>`

### Language / Framework

> `<Primary languages, frameworks, runtimes, and data stores>`

### Key Entry Points

> `<Critical source files, configuration files, routing manifests, or scripts>`

---

## Development Commands

| Task | Command |
|------|---------|
| **Build** | `<Build command, or "No compiled build">` |
| **Test** | `<Command to run unit, integration, or smoke tests>` |
| **Format** | `<Project-native formatter command, or "No formatter configured">` |
| **Lint / Typecheck** | `<Project-native lint, syntax, or typecheck command>` |
| **Run** | `<Command to run the project locally, including host and port when applicable>` |

## Verification Requirements

After editing files:

1. Run the project-native formatter for changed files, if one exists.
2. Run the project-native lint, syntax, or typecheck command.
3. Run relevant tests.
4. Review the diff.
5. Report any failures clearly.

---

## Conventions

### Testing

> `<Test locations, framework, naming conventions, and coverage expectations>`

### Coding Standards

> `<Project-specific style, architecture, import rules, and directory layout>`

### Project-Specific Rules

> `<Business rules, workflow requirements, or repository-specific guidance>`

---

## Context Boundaries

Unless required for the current task, avoid loading generated artifacts,
dependency directories, logs, coverage reports, build outputs, secrets, binary
assets, and local databases.

Project-specific exclusions should be maintained through repository ignore files
instead of weakening global behavior.
