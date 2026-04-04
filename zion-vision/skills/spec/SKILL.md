---
name: "zion-vision:spec"
description: "Extends core spec with visual reference capture and vision-spec.json generation"
user-invocable: true
allowed-tools: Read Write Bash Glob Grep Agent WebFetch
argument-hint: "<feature description, URL, or file path>"
effort: high
---

# /zion-vision:spec — Generate Technical Specification with Visual Contract

You are the orchestrator for specification generation with visual QA capabilities. You extend the `/zion:spec` flow with automatic visual reference capture and `vision-spec.json` generation.

## Input

The user provides one of:
- Natural language description ("Build a product card component")
- Figma URL (https://www.figma.com/file/... or https://www.figma.com/design/...)
- Live URL to a reference page or component
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

### Step 2: Detect Visual Input Type

Examine `$ARGUMENTS` to determine if a visual reference was provided:

- **Figma URL**: matches `figma.com/file/` or `figma.com/design/`
- **Live URL**: starts with `http://` or `https://` (and is not a Figma URL)
- **File path**: points to an existing `.png`, `.jpg`, or `.webp` file
- **Text description**: none of the above

Set `VISUAL_INPUT_TYPE` accordingly (figma | url | file | text).

### Step 3: Capture Visual Reference

**If `VISUAL_INPUT_TYPE` is `figma`:**
```bash
bin/zion-figma-extract "$ARGUMENTS" .sdd/refs/
```
The script outputs a JSON manifest of saved reference screenshot paths. Store these paths for use in `vision-spec.json`.

If the script is unavailable or returns an error, proceed but file a BLOCKER in the spec noting `ref_path` could not be populated.

**If `VISUAL_INPUT_TYPE` is `url`:**
```bash
bin/zion-capture-styles "$ARGUMENTS" .sdd/refs/
```
The script captures screenshots and extracts computed CSS values. Use the screenshot paths for `ref_path` and the CSS values to inform focus area selectors.

If the script is unavailable, proceed but file a BLOCKER in the spec.

**If `VISUAL_INPUT_TYPE` is `file`:**
The file itself is the reference. Copy or note the path directly as `ref_path`.

**If `VISUAL_INPUT_TYPE` is `text`:**
No reference capture needed. `ref_path` will be left empty and noted in Builder Notes.

### Step 4: Detect Project Type

Read root files to identify the project:
- `package.json` → Node.js (check for framework: next, express, fastify, etc.)
- `go.mod` → Go
- `Cargo.toml` → Rust
- `pyproject.toml` or `requirements.txt` → Python
- `Gemfile` → Ruby
- `pom.xml` or `build.gradle` → Java/Kotlin
- `Makefile`, `CMakeLists.txt` → C/C++

Identify: language, framework, test runner, package manager.

### Step 5: Read Codebase

Use Glob to understand directory structure (top 2 levels).
Use Grep to find:
- Existing patterns (how similar features are implemented)
- Naming conventions (camelCase, snake_case, file naming)
- Import patterns (absolute vs relative, barrel files)
- Test patterns (test file location, framework used)

### Step 6: Delegate to Spec Writer

Spawn the `spec-writer` agent with this context:

1. **User's request**: The full `$ARGUMENTS` input
2. **Visual input type**: `VISUAL_INPUT_TYPE` and any captured reference paths
3. **Project type**: Language, framework, test runner, package manager
4. **Codebase conventions**: What you found in Step 5
5. **Template (TECH_SPEC)**: Read `${CLAUDE_PLUGIN_ROOT}/templates/TECH_SPEC.template.md`
6. **Template (vision-spec)**: Read `${CLAUDE_PLUGIN_ROOT}/templates/vision-spec.template.json`

The spec-writer agent (zion-vision version) will:
- Write `.sdd/TECH_SPEC.md`
- Write `.sdd/vision-spec.json` with focus areas and per-breakpoint comparisons
- Self-validate against the spec contract
- Run `zion-validate-spec .sdd/TECH_SPEC.md`

#### vision-spec.json Structure

The agent generates `.sdd/vision-spec.json` based on `templates/vision-spec.template.json`:

```json
{
  "version": "0.1.0",
  "spec_hash": "<sha256 of TECH_SPEC.md>",
  "created_at": "<ISO 8601 timestamp>",
  "focus_areas": [
    {
      "selector": "<CSS selector for the element>",
      "label": "<human-readable label>"
    }
  ],
  "comparisons": [
    {
      "name": "<component or page name>",
      "ref_path": "<path to reference screenshot, relative to project root>",
      "build_url": "<URL where the built component can be viewed>",
      "breakpoints": [
        { "viewport": "mobile", "width": 375 },
        { "viewport": "desktop", "width": 1440 }
      ],
      "focus_areas": ["<selector from top-level focus_areas>"],
      "result": null
    }
  ]
}
```

Rules for the agent:
- Always include at minimum `mobile` (375px) and `desktop` (1440px) breakpoints
- Define at least 3 focus areas per comparison with specific CSS selectors
- `result` is always `null` at spec-write time
- Reference `templates/vision-spec.template.json` for the canonical schema

### Step 7: Validate Output

After the agent returns, verify both outputs exist and are valid:

```bash
zion-validate-spec .sdd/TECH_SPEC.md
```

Also verify `vision-spec.json` is present:
```bash
test -f .sdd/vision-spec.json && echo "vision-spec.json exists"
```

If INVALID: show the issues and ask the user to refine their input or provide more detail.

### Step 8: Write State

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
  "feature": "<detected from spec Goal section>",
  "visual_qa": true
}
```

### Step 9: Summary

Print a concise summary:
```
SPEC READY: <feature name>
  Goal: <1-line goal>
  Acceptance Criteria: <count>
  Files: <count to create> new, <count to modify> modified
  Visual QA: <count> comparisons × <breakpoints> breakpoints, <count> focus areas
  Run /zion-vision:plan to break this into tasks.
```

## Do NOT

- Do not create tasks — that's `/zion-vision:plan`
- Do not implement code — that's `/zion:build`
- Do not modify existing project files — only `.sdd/` and `.sdd/refs/` files
- Do not skip `vision-spec.json` generation for UI features
