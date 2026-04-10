---
name: "zion:spec"
description: "User describes a feature, shares a URL, or points at existing code to extend"
user-invocable: true
allowed-tools: Read Write Bash Glob Grep Agent WebFetch
argument-hint: "<feature description, URL, or file path>"
effort: high
---

# /zion:spec — Generate Technical Specification

You are the orchestrator for specification generation. Your job is to gather context and delegate to the spec-writer agent.

## Input

The user provides one of:
- Natural language description ("Build an auth middleware with JWT")
- URL to documentation or API reference
- Path to existing code to extend or refactor
- Screenshot of a design or architecture diagram

Their input is: `$ARGUMENTS`

## Flow

### Step 1: Initialize .sdd/

If `.sdd/` directory does not exist, create it:
```
mkdir -p .sdd
```

Write `.sdd/.gitignore` if it does not exist:
```
.active
```

Create `.sdd/learnings.md` if it does not exist (task-executor reads this first):
```bash
[ -f .sdd/learnings.md ] || echo "# Learnings" > .sdd/learnings.md
```

### Step 2: Detect Project Type

Read root files to identify the project:
- `package.json` → Node.js (check for framework: next, express, fastify, etc.)
- `go.mod` → Go
- `Cargo.toml` → Rust
- `pyproject.toml` or `requirements.txt` �� Python
- `Gemfile` → Ruby
- `pom.xml` or `build.gradle` → Java/Kotlin
- `Makefile`, `CMakeLists.txt` → C/C++

Identify: language, framework, test runner, package manager.

### Step 3: Read Codebase

Use Glob to understand directory structure (top 2 levels).
Use Grep to find:
- Existing patterns (how similar features are implemented)
- Naming conventions (camelCase, snake_case, file naming)
- Import patterns (absolute vs relative, barrel files)
- Test patterns (test file location, framework used)

### Step 4: Delegate to Spec Writer

Spawn the `spec-writer` agent with this context:

1. **User's request**: The full $ARGUMENTS input
2. **Project type**: Language, framework, test runner, package manager
3. **Codebase conventions**: What you found in Step 3
4. **Template**: Read `${CLAUDE_PLUGIN_ROOT}/templates/TECH_SPEC.template.md` and include it as the expected output format

The spec-writer agent will:
- Write `.sdd/TECH_SPEC.md`
- Self-validate against the spec contract
- Run `zion-validate-spec .sdd/TECH_SPEC.md`

### Step 5: Validate Output

After the agent returns, verify the spec exists and is valid:

```bash
zion-validate-spec .sdd/TECH_SPEC.md
```

If INVALID: show the issues and ask the user to refine their input or provide more detail.

### Step 6: Write State

If valid, compute the spec hash and write state:

```bash
shasum -a 256 .sdd/TECH_SPEC.md | cut -d' ' -f1
```

Write `.sdd/spec-state.json`:
```json
{
  "status": "ready",
  "hash": "sha256:<computed>",
  "created_at": "<ISO-8601>",
  "feature": "<detected from spec Goal section>"
}
```

### Step 7: Summary

Print a concise summary:
```
SPEC READY: <feature name>
  Goal: <1-line goal>
  Acceptance Criteria: <count>
  Files: <count to create> new, <count to modify> modified
  Run /zion:plan to break this into tasks.
```

## Do NOT

- Do not create tasks — that's `/zion:plan`
- Do not implement code ��� that's `/zion:build`
- Do not modify existing project files — only `.sdd/` files
