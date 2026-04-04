# Spec Contract — TECH_SPEC.md Format Rules

This rule defines the mandatory format for all technical specifications in the Zion SDD workflow. It applies to every `.sdd/TECH_SPEC.md` file.

## Mandatory Sections

Every TECH_SPEC.md MUST contain exactly these 8 sections with these exact headings:

1. `## Goal` — 1-2 sentences. What + why. No fluff.
2. `## Constraints` — Language, framework, test runner, dependencies, boundaries. All detected from the project, not assumed.
3. `## Reuse` — Existing code the builder MUST use. Found via Grep/Glob, not assumed. Lists file paths + what they do. Forces the spec-writer to read the codebase and prevents the builder from reinventing the wheel.
4. `## Acceptance Criteria` — Numbered list. Every criterion has a verification command in backticks.
5. `## Architecture` — Three subsections: Files to create, Files to modify, Dependencies between files.
6. `## Edge Cases` — What could go wrong. Based on the actual codebase, not theoretical.
7. `## Out of Scope` — Never empty. Explicit boundaries.
8. `## Builder Notes` — Direct instructions for the task-executor. Patterns to follow, helpers to use, conventions to match. Things that don't fit elsewhere but the builder needs to know.

## Acceptance Criteria Format

```
N. [What should be true] — `[command or assertion that proves it]`
```

Examples:
- `1. Auth middleware rejects expired tokens — \`npm test -- auth.test.ts\``
- `2. Health endpoint returns 200 — \`curl -s -o /dev/null -w '%{http_code}' localhost:8080/health\``

If you cannot write a verification command, the criterion is not testable. Rewrite it.

## Architecture Rules

- Every file path is **relative to project root**
- Files to create: state the purpose
- Files to modify: state what changes and why
- Dependencies: which file imports/uses which
- No file listed without a clear reason

## Absolute Prohibitions

- No TBD, TODO, PLACEHOLDER, or `[to be determined]` anywhere in the spec
- No vague criteria ("should work well", "is fast enough")
- No prose without purpose — every sentence constrains or specifies
- No assumed conventions — if you didn't Grep for it, don't claim it exists

## Anti-Rationalization

| You might think... | Why it's wrong | Do this instead |
|---|---|---|
| "TBD is fine for now, I'll fill it later" | Later never comes. The builder reads it now. | Fill it or declare a BLOCKER. |
| "The acceptance criterion is obvious, no command needed" | Obvious to whom? The builder is a fresh agent. | Write the command. Always. |
| "Out of Scope is empty because everything is in scope" | No feature has infinite scope. Think harder. | List at least 2 boundaries. |
| "This file probably exists" | Probably ≠ verified. | Glob for it. Confirm. |
| "Reuse is empty, this is all new code" | No codebase is empty. There are always utils, patterns, conventions to follow. | Grep for similar patterns. List at least the conventions. |
| "Builder Notes is obvious, skip it" | Obvious to you ≠ obvious to a fresh agent with zero context. | Write the notes. Be explicit. |
