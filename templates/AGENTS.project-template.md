# Project AGENTS.md

## Project Context

- Purpose:
- Users:
- Tech stack:
- Architecture:
- Constraints:
  - Preserve user-owned files by default.
  - Document any platform-specific limitations.
  - Maintain backward compatibility unless explicitly approved.
  - Keep changes scoped to the project's intended boundaries.

## Testing Requirements

### Bug Fixes

- Reproduce the issue when practical.
- Verify the issue is resolved.
- Verify no regression was introduced.

### Features

- Verify intended behavior.
- Verify existing behavior remains intact.
- Prefer safe validation methods before modifying production behavior.
- Maintain platform parity where applicable.

### Refactoring

- Verify behavior before and after remains unchanged.

Never claim success without validation.

## Repository Rules

### Build Commands

text <build command(s)> 

### Test Commands

text <test command(s)> 

### Local Run Commands

text <local execution command(s)> 

### Validation Commands

text <validation or dry-run command(s)> 

### Deployment Requirements

- Document deployment process.
- Document release requirements.
- Document versioning requirements.
- Document rollback expectations.

## Architectural Rules

### Change Safety

Before modifying behavior:

- Verify current behavior.
- Verify upgrade behavior.
- Verify rollback behavior.
- Verify validation workflows.
- Verify existing user workflows continue to work.
- Verify existing public interfaces remain functional.

### User-Facing Behavior

Preserve:

- User prompts
- Visible output
- Confirmation flows
- Progress indicators
- Logging expectations
- Verification steps

Do not suppress, remove, or alter user-facing behavior unless explicitly requested.

### Backward Compatibility

- Preserve public APIs unless explicitly approved.
- Preserve public CLI flags unless explicitly approved.
- Preserve documented workflows unless explicitly approved.
- Preserve existing integrations unless explicitly approved.

### Project Boundaries

- Keep changes within the project's intended scope.
- Do not modify unrelated systems.
- Do not overwrite user-owned assets without approval.
- Respect documented ownership boundaries.

### Data and Configuration

- Preserve configuration compatibility.
- Preserve migration compatibility.
- Preserve existing data formats unless approved.
- Document any breaking changes.

### Dependencies

- No new dependencies without approval.
- Prefer existing project patterns before introducing new tooling.
- Reuse established libraries and frameworks when practical.

### Performance and Efficiency

Performance improvements must not alter behavior.

Preserve:

- Functional behavior
- User workflows
- Validation paths
- Security controls
- Safety checks

Optimize implementation, not functionality.

## Definition of Done

A task is complete only when:

- Requested behavior exists.
- Validation was performed.
- Relevant tests pass.
- No unrelated code was modified.
- Assumptions and risks are documented.
- Results are summarized.

## Project-Specific Rules

Add repository-specific requirements here.

Examples:

- Coding standards
- Security requirements
- Deployment restrictions
- Platform-specific constraints
- Regulatory requirements
- Architecture conventions
- Environment requirements
- Repository workflows