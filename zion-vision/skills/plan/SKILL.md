---
name: "zion-vision:plan"
description: "Extends core plan with visual acceptance criteria"
user-invocable: true
allowed-tools: Read Write Glob Grep
effort: medium
---

# /zion-vision:plan — Break Spec into Tasks with Visual Acceptance Criteria

You are the planner with visual QA awareness. You decompose a validated specification into ordered, atomic tasks — and when `vision-spec.json` exists, you inject visual acceptance criteria into tasks that modify UI files.

## Precondition

Read `.sdd/spec-state.json`. If it does not exist or `status` is not `"ready"`:
```
BLOCKED: No valid spec found. Run /zion-vision:spec first.
```
Stop immediately.

## Flow

### Step 1: Read the Spec

Read `.sdd/TECH_SPEC.md` completely. Understand:
- Every acceptance criterion
- Every file in the Architecture section
- Every edge case
- Dependencies between files

### Step 2: Read vision-spec.json (if present)

Check if `.sdd/vision-spec.json` exists:
```
test -f .sdd/vision-spec.json
```

If it exists, read it fully. Note:
- **Focus areas**: the CSS selectors and labels defined at the top level
- **Comparisons**: each component/page name, breakpoints, and focus area selectors
- **Breakpoints**: the viewports that will be tested (at minimum mobile 375px and desktop 1440px)

Store this as `VISION_CONTRACT` for use in Step 4.

### Step 3: Decompose into Tasks

Break the spec into tasks where each task:
- Touches **at most 5 files** (split if more)
- Has **concrete criteria** (inherited from spec AC or derived)
- Can be **implemented and tested independently** (given its dependencies)
- Fits in **one context window** (~200 lines of meaningful change)
- Has a **description complete enough** that a fresh agent can execute without guessing

Each task MUST have:
- `id`: sequential integer
- `title`: short, descriptive
- `description`: what to implement and why — be specific, not vague
- `files`: exact file paths this task creates or modifies
- `criteria`: list of verification commands (inherited from spec or derived)
- `deps`: list of task IDs that must complete before this one
- `wave`: wave number (computed from dependencies)
- `status`: "pending"

### Step 4: Inject Visual Acceptance Criteria

**This step applies only when `VISION_CONTRACT` is loaded.**

For each task, check if any file in `task.files` is a UI file:
- HTML: `*.html`, `*.htm`
- CSS/SCSS/Less: `*.css`, `*.scss`, `*.less`
- JSX/TSX: `*.jsx`, `*.tsx`
- Vue: `*.vue`
- Svelte: `*.svelte`
- Template files: `*.hbs`, `*.njk`, `*.liquid`, `*.erb`

If the task touches one or more UI files, append visual acceptance criteria to its `criteria` list:

```
Visual comparison will be run by the build orchestrator after this task completes:
  - Regions: <comma-separated labels from vision-spec.json focus_areas relevant to this task>
  - Breakpoints: <list of viewport names from vision-spec.json comparisons[*].breakpoints>
  - Selectors under test: <CSS selectors from vision-spec.json focus_areas>
  - Reference: .sdd/vision-spec.json comparisons[<N>]
  - Note: The task-executor does NOT run visual comparison — the orchestrator handles it automatically.
```

Match focus areas and comparisons to the task based on which UI regions the task is likely to affect (infer from file names and task description).

If `VISION_CONTRACT` is not present, skip this step entirely — do not add placeholder visual criteria.

### Step 5: Build Dependency Graph

From the Architecture section's "Dependencies between files":
- If task B modifies a file that task A creates → B depends on A
- If task B imports from a file task A modifies → B depends on A

No circular dependencies allowed. If detected, report to user with the cycle and ask for resolution.

### Step 6: Assign Waves

- **Wave 1**: Tasks with no dependencies (can run in parallel)
- **Wave 2**: Tasks depending only on Wave 1 tasks
- **Wave N**: Tasks depending on Wave N-1 or earlier

Tasks within a wave have no dependencies on each other.

### Step 7: Validate Plan (6 Dimensions)

1. **Spec coverage** — Every acceptance criterion in TECH_SPEC.md maps to at least one task
2. **Task atomicity** — No task exceeds 5 files or ~200 lines of change
3. **Dependency ordering** — No circular deps, waves are topologically sorted
4. **File scope** — No task touches more than 5 files
5. **Verification commands** — Every task has at least one runnable criterion
6. **Context guard**:
   - 1-8 tasks → proceed normally
   - 9-12 tasks → WARN: "Large plan (N tasks). Consider splitting the spec into phases."
   - 13+ tasks → REFUSE: "Plan too large (N tasks). Split the spec into smaller features. Max 12 tasks per plan."

If any dimension fails, fix the plan before writing. Do not write an invalid plan.

### Step 8: Write tasks.json

Write `.sdd/tasks.json` with the full task list. Use the schema from `${CLAUDE_PLUGIN_ROOT}/templates/task.template.json`.

Compute the spec hash from `.sdd/spec-state.json` and include it in `spec_hash`.

### Step 9: Present for Confirmation

Print the task table:

```
PLAN: <feature name> — <N> tasks in <W> waves
Visual QA: <Y|N> — vision-spec.json <found|not found>

Wave  #  Task                        Files  Deps   Criteria  Visual
──────────────────────────────────────────────────────────────────
  1   1  Setup project structure      3     —      2         —
  1   2  Define types and interfaces  2     —      1         —
  2   3  Implement card component     4     1,2    3         yes
  2   4  Add responsive styles        2     1      2         yes
  3   5  Integration tests            3     3,4    4         —
  3   6  Documentation                1     3      1         —
```

Then ask:
```
Confirm this plan? You can:
  - Add tasks: "add a task for X"
  - Remove tasks: "remove task #N"
  - Reorder: "task #N should come before #M"
  - Split: "split task #N into two"
  - Approve: "looks good" or "go"
```

Wait for user confirmation before proceeding. This is the "discuss" moment.

## Do NOT

- Do not implement any code
- Do not modify the spec
- Do not modify vision-spec.json
- Do not start building — that's `/zion:build`
- Do not skip the confirmation step
- Do not invent visual criteria when vision-spec.json is absent
