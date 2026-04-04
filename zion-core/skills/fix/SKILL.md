---
name: "zion:fix"
description: "Verification failures exist, a task is blocked, or user reports a bug to fix"
user-invocable: true
allowed-tools: Read Write Edit Bash Glob Grep Agent
argument-hint: "[bug description] [--task N] [--auto]"
---

# /zion:fix — Diagnose and Fix

You are the fix orchestrator. You diagnose failures, create targeted fix tasks, execute them with fresh agents, and re-verify. You bridge the gap between "verify found problems" and "problems are solved."

## Three Modes

Parse flags from `$ARGUMENTS`:
```bash
zion-parse-flags "$ARGUMENTS"
```

| Mode | Trigger | Behavior |
|------|---------|----------|
| **Auto** | `/zion:fix` or `/zion:fix --auto` | Read verify-state.json failures → diagnose all → fix all → re-verify |
| **Manual** | `/zion:fix "auth rejects valid tokens"` | User describes bug → diagnose → fix → re-verify affected criteria |
| **Retry** | `/zion:fix --task 4` | Re-attempt a blocked task with fresh context + learnings from failure |

## Precondition

At least one of these must be true:
- `.sdd/verify-state.json` exists with failures (auto mode)
- User provides a bug description (manual mode)
- `.sdd/tasks.json` has a task with status "blocked" (retry mode)

If none: `Nothing to fix. Run /zion:verify to check for issues.`

## Flow

### Phase 1: Collect Evidence

**Auto mode:**
1. Read `.sdd/verify-state.json` — collect all criteria with `"status": "fail"`
2. For each failure, note which level failed (exists/substantive/wired/functional) and the evidence
3. Read `.sdd/learnings.md` — check if similar issues were seen before
4. Read `.sdd/build-log.json` — check which tasks produced the failing code

**Manual mode:**
1. Read user's bug description from $ARGUMENTS
2. Read `.sdd/TECH_SPEC.md` — find related acceptance criteria
3. Read `.sdd/learnings.md` — check for related patterns
4. Use Grep to find the relevant code

**Retry mode:**
1. Read the blocked task from `.sdd/tasks.json` (by --task ID)
2. Read its `blocked_reason` — understand what was tried and failed
3. Read `.sdd/learnings.md` — check if other tasks solved similar issues since the block

### Phase 2: Diagnose

For each failure/bug, spawn a **diagnostic pass** (NOT a fix yet):

Spawn Agent(task-executor) with diagnostic prompt:
```
You are diagnosing a failure, NOT fixing it yet.

FAILURE: [criterion that failed]
EVIDENCE: [error output, failed level, what was tried]
LEARNINGS: [relevant entries from learnings.md]

Tasks:
1. Read the code involved
2. Identify the root cause (not symptoms)
3. Determine the minimal change needed
4. List exactly which files need to change

Report format:
ROOT_CAUSE: [1-2 sentences]
FILES: [list of files to change]
FIX: [what to change, specifically]
RISK: [what else could break]
```

### Phase 3: Create Fix Tasks

From the diagnoses, create fix tasks in `.sdd/tasks.json`:

- Each fix task gets ID starting from `max(existing IDs) + 1`
- Status: `"pending"`
- Title: `"fix: [short description of what's being fixed]"`
- Wave: next wave number after existing waves
- Criteria: the specific verification commands that currently fail
- Files: from the diagnosis

For retry mode: reset the blocked task's status to `"pending"`, cycles to `0`, clear `blocked_reason`. Add diagnostic learnings to the task description.

### Phase 4: Execute Fixes (The Fix Loop)

Same loop as `/zion:build` Phase 2, but ONLY for fix tasks:

```
FIX LOOP:
  1. Pick next fix task (pending, deps met)
  2. Write .sdd/.active
  3. Spawn fresh Agent(task-executor) with:
     - Fix task (includes root cause diagnosis)
     - learnings.md (includes what was tried before)
     - Original task context (what was the intent)
  4. Agent executes: read → fix → test → report
     - 3 cycle circuit breaker (same as build)
  5. On DONE: stage, commit as "fix(zion): [description]", update tasks.json
  6. On BLOCKED: update tasks.json, log to learnings
  7. Delete .sdd/.active
  8. Update build-log.json
  9. GOTO FIX LOOP
```

### Phase 5: Re-Verify (Targeted)

After all fix tasks complete (or block):

1. Collect ONLY the criteria that were failing (not all criteria)
2. Run 4-level verification on those specific criteria
3. Update `.sdd/verify-state.json` — merge new results with existing

```
RE-VERIFY: 3 criteria
  PASS  Token rejects expired    ████ exists ✓ substantive ✓ wired ✓ functional ✓  ← was FAIL
  PASS  Rate limiter 100 req/min ████ exists ✓ substantive ✓ wired ✓ functional ✓  ← was FAIL
  FAIL  WebSocket reconnect      ███░ exists ✓ substantive ✓ wired ✓ functional ✗  ← still FAIL
```

### Phase 6: Summary

```
FIX COMPLETE: <feature>
─────────────────────────────────────
Fixed: 2/3 failures resolved
Still failing: 1 (WebSocket reconnect — blocked after 3 cycles)

Fix  Criterion                  Before  After   Cycles
───────────────────────────────────────────────────────
 #9  Token rejects expired      FAIL    PASS    1/3
#10  Rate limiter 100 req/min   FAIL    PASS    2/3
#11  WebSocket reconnect        FAIL    FAIL    3/3 ← BLOCKED

BLOCKED: #11 — mock WebSocket server not responding (see learnings.md)
```

Append fix summary to `.sdd/learnings.md`.

If ALL failures resolved: print "All clear. Run /zion:status for full dashboard."
If some still fail: print remaining failures with blocked reasons.

## Relationship with /zion:build

The build pipeline (Phase 4) runs this fix logic automatically after verify. You do NOT need to run `/zion:fix` manually after a build — it's already integrated.

Use `/zion:fix` standalone for:
- Bugs found AFTER build+verify completed (manual mode)
- Retrying blocked tasks with fresh diagnosis (retry mode)
- Re-running auto-fix after user resolves an external blocker (auto mode)

## Do NOT

- Do NOT modify the spec — fixes are patches, not redesigns
- Do NOT skip the diagnostic phase — understand before fixing
- Do NOT fix more than what's broken — scope discipline applies to fixes too
- Do NOT retry a blocked fix without user intervention — 3 cycles is the limit
- Do NOT run full verify — only re-check the affected criteria
