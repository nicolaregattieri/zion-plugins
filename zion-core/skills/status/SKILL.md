---
name: "zion:status"
description: "User asks about SDD progress, or at any point during the workflow"
user-invocable: true
allowed-tools: Read Glob
---

# /zion:status — Progress Dashboard

Display a quick, scannable overview of the current SDD state. Works at any point in the workflow, with partial state.

## Flow

### Step 1: Read State Files

Check for and read each state file. Handle missing files gracefully:

- `.sdd/spec-state.json` → spec status, feature name, hash
- `.sdd/TECH_SPEC.md` → AC count (count numbered lines under ## Acceptance Criteria)
- `.sdd/tasks.json` → task list, waves, statuses, cycles
- `.sdd/build-log.json` → timing data
- `.sdd/verify-state.json` → verification results
- `.sdd/.active` → currently executing task
- `.sdd/learnings.md` → pattern count, task log entry count

### Step 2: Compute Metrics

From tasks.json:
- Total tasks, tasks per status (done, blocked, pending)
- Number of waves
- Total cycles used vs max possible

From build-log.json:
- Total elapsed time
- Per-task duration

From verify-state.json:
- Total criteria, pass/fail counts, pass rate

### Step 3: Print Dashboard

```
ZION STATUS
══════════��════════════════════════════════════════════

SPEC: <feature> (<status>)                       hash: <short>
PLAN: <N> tasks | <W> waves                      created: <date>
BUILD: <done>/<total> done | <blocked> blocked | <pending> pending
VERIFY: <pass>/<total> pass (<rate>%)             last: <date>

Wave  Task                        Status     Cycles  Time
─────────────��─────────────────────────────────────────────
  1   Setup project               done       1/3     0:42
  1   Auth types                  done       1/3     0:28
  2   Auth middleware             done       2/3     1:15
  2   Token validation            blocked    3/3     2:01
  2   Route guards                done       1/3     0:55
  3   Integration tests           pending    —       —
  3   Error handling              pending    —       —
  3   Rate limiter                done       1/3     0:48

BLOCKED: #4 token-validation — mock server timeout (see learnings.md)
NEXT: wave 3 ready (#6 integration-tests, #7 error-handling)
ACTIVE: #5 route-guards (in progress)

LEARNINGS: <N> patterns, <M> task entries
```

### Partial State Handling

If only some files exist, show what's available:

- No `.sdd/` → "No SDD project in this directory. Run /zion:spec to start."
- Only spec-state.json → show SPEC line only, suggest /zion:plan
- Spec + tasks.json → show SPEC + PLAN + BUILD lines, suggest /zion:build
- Everything → full dashboard

### Active Task

If `.sdd/.active` exists, show which task is currently being executed:
```
ACTIVE: #3 auth-middleware (in progress)
```

## Do NOT

- Do not modify any state files — status is read-only
- Do not suggest fixes for blocked tasks — just report
- Do not run tests or commands — just read existing state
