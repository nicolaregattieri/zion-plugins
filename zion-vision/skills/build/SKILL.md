---
name: "zion-vision:build"
description: "Extends core build loop with automatic visual comparison after UI tasks"
user-invocable: true
allowed-tools: Read Write Edit Bash Glob Grep Agent
argument-hint: "[--safe] [--dry] [--pr]"
effort: high
---

# /zion-vision:build — Execute Tasks with Visual Comparison

This skill extends `/zion:build` with automatic visual comparison after UI tasks complete. All core build behavior is preserved; visual comparison is additive.

## Flags

Parse flags from `$ARGUMENTS` (same as core build):

| Flag | Behavior |
|------|----------|
| (none) | Full auto: implement, verify, commit each task |
| `--safe` | Show each task before executing. Wait for user OK. |
| `--dry` | Full auto but do NOT commit. Stage files only. |
| `--pr` | Full auto + commits + create GitHub PR at the end |

## Precondition

Read `.sdd/tasks.json`. If it does not exist or has no `"pending"` tasks:
```
BLOCKED: No pending tasks. Run /zion:plan first (or all tasks are already done).
```

## Phase 0: Branch Management

Same as `/zion:build` Phase 0.

## Phase 1: Resume Check

Same as `/zion:build` Phase 1.

## Phase 2: The Loop

```
LOOP:
  1-5. Same as /zion:build steps 1-5.

  6. Spawn fresh Agent(task-executor) — same as /zion:build step 6.

  7. Parse agent result:

     On DONE:
       - Stage the specific files listed in the task (git add <file1> <file2>...)
       - Unless --dry: commit with message "feat(zion): <task title>"
       - Update .sdd/tasks.json:
           status → "done"
           completed_at → ISO timestamp
           commit_sha → git rev-parse HEAD (or "staged" if --dry)
           cycles → from agent report
       - Append agent's learnings to .sdd/learnings.md

       ── VISION EXTENSION ──
       Check if this task is a UI task:
         A task is a UI task if ANY of the following are true:
           a) Its files list includes paths ending in .html, .css, .jsx, .tsx, .vue, or .svelte
           b) Its criteria mention visual or layout properties (color, spacing, font, px, rem, %)

       If UI task AND .sdd/vision-spec.json exists:
         Run visual comparison logic (same as /zion-vision:compare) on all pending comparisons
         relevant to this task's modified selectors/components.

         The comparison result is written to vision-spec.json as usual.
         If comparison result is "fail":
           - The task status remains "done" (code is complete)
           - The vision-spec.json records the failure with fidelity < 95%
           - Print a warning:
             VISION WARNING: Task #N passed code checks but visual comparison FAILED
               Comparison : <name>
               Fidelity   : <X>%
               Diffs      : <count> remaining diffs
             Run /zion-vision:compare to inspect and retry.
         If comparison result is "pass":
           Print:
             VISION PASS: Task #N — <comparison-name> fidelity <X>%

       If not a UI task OR no vision-spec.json: skip visual comparison entirely.
       ──────────────────────

     On BLOCKED:
       - Update .sdd/tasks.json:
           status → "blocked"
           blocked_reason → from agent report
           cycles → 3
       - Append failure details to .sdd/learnings.md
       - No visual comparison for blocked tasks.

     On TASK_GAP:
       - Update .sdd/tasks.json:
           status → "blocked"
           blocked_reason → "TASK_GAP: <details>"
           cycles → 0
       - Print gap details to user. Ask if they want to clarify and retry.
       - No visual comparison for TASK_GAP tasks.

  8-11. Same as /zion:build steps 8-11.
```

## Phase 3: Self-Review

Same as `/zion:build` Phase 3.

## Phase 4: Summary

Same as `/zion:build` Phase 4, with one addition.

After the core summary table, if any visual comparisons ran during this build, append:

```
VISION QA SUMMARY
──────────────────────────────────────────────────
  Comparisons run : N
  Passed          : N (fidelity >= 95%)
  Failed          : N (recorded in vision-spec.json)

Run /zion-vision:status to view full vision QA details.
```

## UI Task Detection Rules

To determine if a task modifies UI files, check the task's `files` array:

```bash
# Extensions that indicate a UI task
UI_EXTENSIONS=".html .css .scss .sass .less .jsx .tsx .vue .svelte"
```

Non-UI tasks (e.g., those only touching `.json`, `.md`, `.ts` non-component files, `.sh`, `.go`) do not trigger visual comparison.

## Do NOT

- Do NOT implement code yourself — always delegate to task-executor agent
- Do NOT carry context between tasks — each agent is fresh
- Do NOT retry a BLOCKED task — it needs human intervention
- Do NOT skip the circuit breaker — 3 cycles is the hard limit
- Do NOT commit to main/master — always on feature branch
- Do NOT block task completion on visual comparison failure — code DONE is DONE
- Do NOT run visual comparison if vision-spec.json does not exist
