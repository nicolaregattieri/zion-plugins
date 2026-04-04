# Tech Spec: [Feature Name]

## Goal
[1-2 sentences. What this feature does and why it exists.]

## Constraints
- Language: [detected from project]
- Framework: [detected from project]
- Test runner: [detected from project]
- Dependencies: [existing deps to use, new deps to add]
- Boundaries: [what this feature can and cannot touch]

## Reuse
[Existing code the builder MUST use instead of creating new. Found via Grep/Glob.]
- `path/to/existing/util` — [what it does, how to use it]
- `path/to/existing/pattern` — [follow this pattern for consistency]

## Acceptance Criteria
1. [Criterion] — `[verification command or assertion]`
2. [Criterion] — `[verification command or assertion]`

## Architecture
### Files to create
- `path/to/new/file` — [purpose]

### Files to modify
- `path/to/existing/file` — [what changes and why]

### Dependencies between files
- `file-a` depends on `file-b` (imports X)

## Edge Cases
1. [What could go wrong and how to handle it]

## Out of Scope
- [Explicitly what this spec does NOT cover]

## Builder Notes
[Direct instructions for the task-executor. Things that don't fit elsewhere.]
- [e.g., "Use the helper at src/utils/db.ts for all database calls"]
- [e.g., "Follow the pattern in src/routes/users.ts for new routes"]
