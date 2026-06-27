# AGENTS.project-template.md

> Project-specific instructions. Inherits global behavior from `~/.codex/AGENTS.md`.

---

# Project AGENTS.md

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

---

## Verification Requirements

In addition to the global verification and diff review workflows:

1. Run the project-native formatter for changed files, if one exists.
2. Run the project-native lint, syntax, or typecheck command.
3. Run relevant project-level tests.

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

Project-specific exclusions should be maintained through repository ignore files instead of weakening global behavior.

Rely on the global token-saver boundaries for standard exclusions, including:

- generated artifacts
- dependency directories
- build outputs
- logs
- coverage reports
- local databases
- binary assets
- secrets