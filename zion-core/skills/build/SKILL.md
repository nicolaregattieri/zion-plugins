---
name: "zion:build"
description: "After /zion:plan produces valid tasks, or to resume an interrupted build"
user-invocable: true
allowed-tools: Read Write Edit Bash Glob Grep Agent
argument-hint: "[--safe] [--dry] [--pr]"
---

# /zion:build — Execute Tasks (The Loop)

You are the build orchestrator. You execute tasks one by one, spawning a fresh agent for each. You never implement code yourself — you coordinate, track state, and enforce the protocol.

## Flags

Parse flags from `$ARGUMENTS`:
```bash
zion-parse-flags "$ARGUMENTS"
```

| Flag | Behavior |
|------|----------|
| (none) | Full auto: implement, verify, commit each task |
| `--safe` | Show each task before executing. Wait for user OK. |
| `--dry` | Full auto but do NOT commit. Stage files only. |
| `--pr` | Full auto + commits + create GitHub PR at the end |

Flags combine: `--dry --safe` = approve each task, no commits.

## Precondition

Read `.sdd/tasks.json`. If it does not exist or has no `"pending"` tasks:
```
BLOCKED: No pending tasks. Run /zion:plan first (or all tasks are already done).
```

## Phase 0: Branch Management

```bash
BRANCH=$(git branch --show-current 2>/dev/null)
```

- If on `main` or `master`: read `.sdd/spec-state.json` for feature name, create and checkout `feat/<feature-name>`
- If already on a feature branch: stay on it
- If not a git repo: skip branching (still build, just no commits)

## Phase 1: Resume Check

Read `.sdd/tasks.json`:
- If tasks with status `"done"` exist → this is a resume. Report what's done:
  ```
  RESUMING: 3/8 tasks already done. Continuing from task #4.
  ```
- Read `.sdd/learnings.md` for accumulated context (if exists)

Initialize `.sdd/build-log.json` if not exists:
```json
{"started_at": "<ISO>", "tasks": []}
```

## Phase 2: The Loop

```
LOOP:
  1. Read .sdd/tasks.json
  2. Find next task: status == "pending" AND all deps have status == "done"
     - If none found AND blocked tasks exist:
       Print blocked tasks with reasons. STOP.
     - If none found AND all tasks done:
       Exit loop → Phase 3.
  3. If --safe: print task details (title, files, criteria, deps). Wait for user "go" or "skip".
  4. Write task ID to .sdd/.active
  5. Record start time

  6. Spawn fresh Agent(task-executor) with this prompt:
     ---
     You are executing task #N of the Zion SDD plan.

     ## Task
     <full task object from tasks.json as JSON>

     ## Learnings
     <contents of .sdd/learnings.md>

     ## Project
     - Language: <detected>
     - Framework: <detected>
     - Test runner: <detected>

     Execute this task following the execution protocol.
     Report DONE, BLOCKED, or TASK_GAP when finished.
     ---

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

     On BLOCKED:
       - Update .sdd/tasks.json:
           status → "blocked"
           blocked_reason → from agent report
           cycles → 3
       - Append failure details to .sdd/learnings.md

     On TASK_GAP:
       - Update .sdd/tasks.json:
           status → "blocked"
           blocked_reason → "TASK_GAP: <details>"
           cycles → 0
       - Print gap details to user. Ask if they want to clarify and retry.

  8. Delete .sdd/.active

  9. Append to .sdd/build-log.json:
     {"task_id": N, "status": "done|blocked", "cycles": N, "duration_s": N, "commit": "sha|null"}

  10. Print progress: "Task #N <title>: DONE (cycle 1/3) | 4/8 complete"

  11. GOTO LOOP
```

## Phase 3: Self-Review

After all tasks complete (or all remaining are blocked):

1. If git repo and not --dry:
   ```bash
   git diff main...HEAD
   ```
2. Review ONLY for critical issues: security vulnerabilities, broken imports, obvious bugs
3. If critical issues found: fix, stage specific files, commit as `fix(zion): resolve <issue>`
4. Do NOT nitpick style, naming, or suggest improvements. Only fix what would break or is unsafe.

## Phase 4: Auto-Verify + Auto-Fix

After self-review, automatically run the verify→fix loop. This is the same logic as `/zion:fix` auto mode, embedded in the build pipeline so the user gets a complete result from a single command.

1. Run `/zion:verify` logic — 4-level check on all acceptance criteria
2. Write `.sdd/verify-state.json` with results
3. If ALL pass → proceed to Phase 5 (Summary)
4. If failures exist → run `/zion:fix` auto-mode logic:
   - Max 2 fix rounds
   - Each round: diagnose (fresh agent) → create fix tasks → execute (3-cycle breaker) → re-verify failed criteria only
   - Round 1 catches real bugs, Round 2 catches cascading issues from Round 1 fixes
   - After Round 2, any remaining failures are marked BLOCKED
   - Total max attempts per failure: 2 rounds × 3 cycles = 6 attempts
5. Update `.sdd/verify-state.json` with final results

## Phase 5: Summary

1. Read `.sdd/build-log.json`
2. Update `.sdd/learnings.md` with a `## Project State` section at the top:
   ```
   ## Project State
   [2-3 lines describing what the project can do RIGHT NOW.
   Written for a future session with zero prior context.]
   ```
3. Print summary:
   ```
   BUILD COMPLETE: <feature>
   ────���────────────────────────
   Tasks: N/M done | K blocked
   Commits: N
   Duration: Xm

   Wave  Task                     Status    Cycles
   ──────────────────────────────────────────────────
     1   Setup project            done      1/3
     2   Auth middleware           done      2/3
     2   Token validation         blocked   3/3
     3   Integration tests        done      1/3

   BLOCKED: #4 — mock server timeout

   Run /zion:fix --task 4 to retry with fresh diagnosis.
   ```

4. If blocked tasks or unresolved verify failures exist: report them with reasons
5. If `--dry`: list staged files + suggest commit message(s)
6. If `--pr`:
   - Push branch (ask user for confirmation per git-control rules)
   - Create PR: `gh pr create --title "<feature goal>" --body "<build-log summary>"`
7. If all tasks done AND `.sdd/verify-state.json` exists with all pass:
   Archive to `.sdd/archive/<feature>-<date>/` (keep learnings.md at root)

## Do NOT

- Do NOT implement code yourself — always delegate to task-executor agent
- Do NOT carry context between tasks — each agent is fresh
- Do NOT retry a BLOCKED task — it needs human intervention
- Do NOT skip the circuit breaker — 3 cycles is the hard limit
- Do NOT commit to main/master — always on feature branch
