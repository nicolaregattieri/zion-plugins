# Zion Core — Product Requirements Document

**Version:** 0.1.0
**Author:** Nic Regattieri / Pivotree
**Date:** 2026-04-03
**Status:** Draft

---

## 1. Vision

Zion Core is a Claude Code plugin that implements Spec-Driven Development (SDD) — a structured, repeatable workflow where every feature goes through: **specify → plan → build → verify**. It is project-agnostic, language-agnostic, and framework-agnostic.

The plugin exists because coding agents fail in predictable ways: they skip understanding, dive into code, claim work is done without evidence, and degrade over long sessions. Zion prevents all of this through enforced specifications, fresh-context execution, and blocking quality gates.

**One sentence:** Zion turns "build me X" into a pipeline that produces verified, committed, traceable code — or blocks until it does.

---

## 2. Target User

Any developer using Claude Code who works on features that take more than one shot to implement. Specifically:

- Solo developers building multi-file features
- Team leads who want reproducible AI-assisted workflows
- Developers who've been burned by AI agents that produce incomplete or buggy code
- Anyone who wants to walk away and come back to a coherent state

**Not for:** Trivial one-liners, config tweaks, or questions. Those don't need a spec.

---

## 3. Design Principles

### 3.1 Lean by default
5 commands. 2 agents. 2 hooks. One state directory. Research is embedded in `/zion:spec`, not a separate step. Discussion happens naturally in `/zion:plan`. No command exists without a clear, unique job.

### 3.2 Gates that BLOCK
Hooks return exit code 2 to prevent the agent from finishing. Not warnings. Not suggestions. The session cannot end with incomplete work. This is the single biggest differentiator from every other tool in the space.

### 3.3 Fresh context per task
Every task in `/zion:build` spawns a new agent with clean context. The orchestrator never does implementation work. This prevents the context rot that causes agents to degrade over long sessions. Cross-task knowledge is persisted to `learnings.md`, not kept in conversation.

### 3.4 Measured verification
`/zion:verify` doesn't ask "does this look right?" It checks 4 levels: Exists → Substantive → Wired → Functional. Each criterion gets evidence. Numbers, not vibes.

### 3.5 State survives sessions
All meaningful state is written to `.sdd/` as JSON and Markdown. A new session can pick up exactly where the last one stopped. No context-dependent memory. No "where was I?"

### 3.6 Autonomous by default, controllable when needed
The build loop runs without asking questions — it decides and documents. But flags (`--dry`, `--safe`, `--pr`) give the user control when they want it. One command, multiple behaviors.

---

## 4. Commands

### 4.1 `/zion:spec` — Generate Technical Specification

**Purpose:** Transform a user's intent into a precise, machine-readable specification that a builder agent can follow without judgment calls.

**Input:** One of:
- Natural language description ("Build an auth middleware with JWT")
- URL to documentation or API reference
- Path to existing code to extend or refactor
- Screenshot of a design or architecture diagram

**Process:**
1. **Detect project type.** Read root files (package.json, go.mod, Cargo.toml, pyproject.toml, requirements.txt, Makefile, etc.) to identify language, framework, test runner, and conventions.
2. **Read codebase.** Use Glob and Grep to understand existing patterns, naming conventions, directory structure, and dependencies. The spec must align with what's already there.
3. **Delegate to `spec-writer` agent** (opus model). The agent receives the user's input + codebase context and produces the specification.
4. **Self-validate.** The agent runs a checklist before declaring done:
   - No sections with TBD, TODO, or placeholder text
   - Every acceptance criterion is testable (has a command, assertion, or measurable output)
   - Every file path in Architecture is either an existing file or a new file with clear purpose
   - Constraints section lists actual dependencies from the project (not assumed)
   - Out of Scope section is non-empty (forces explicit boundary thinking)
5. **Write state.** Save `.sdd/spec-state.json` with status, hash, timestamp.

**Output:** `.sdd/TECH_SPEC.md`

**TECH_SPEC.md format:**

```markdown
# Tech Spec: [Feature Name]

## Goal
[1-2 sentences. What this feature does and why it exists.]

## Constraints
- Language: [detected from project]
- Framework: [detected from project]
- Test runner: [detected from project]
- Dependencies: [existing deps to use, new deps to add]
- Boundaries: [what this feature can and cannot touch]

## Acceptance Criteria
1. [Criterion] — `[verification command or assertion]`
2. [Criterion] — `[verification command or assertion]`
...

## Architecture
### Files to create
- `path/to/new/file.ts` — [purpose]

### Files to modify
- `path/to/existing/file.ts` — [what changes and why]

### Dependencies between files
- `file-a.ts` depends on `file-b.ts` (imports X)

## Edge Cases
1. [What could go wrong and how to handle it]

## Out of Scope
- [Explicitly what this spec does NOT cover]
```

**Failure modes:**
- User provides vague input ("make it better") → Agent asks clarifying questions, does not generate spec
- Codebase has no detectable conventions → Agent flags this as a constraint, doesn't assume
- Conflicting requirements → Agent lists conflicts as BLOCKERs, does not proceed

---

### 4.2 `/zion:plan` — Break Spec into Tasks

**Purpose:** Decompose a validated spec into ordered, atomic tasks that can each be completed in a single agent context window.

**Precondition:** `.sdd/spec-state.json` exists with `status: "ready"`. Refuses if spec is missing or invalid.

**Process:**
1. **Read spec.** Parse all sections of `.sdd/TECH_SPEC.md`.
2. **Decompose.** Break into tasks where each task:
   - Touches at most 5 files
   - Has concrete acceptance criteria (inherited from spec or derived)
   - Can be implemented and tested independently (given its dependencies)
   - Fits in one context window (~200 lines of meaningful change)
3. **Build dependency graph.** Identify which tasks must come before others based on file dependencies in the Architecture section.
4. **Assign waves.** Group independent tasks into waves. Tasks within a wave have no dependencies on each other. Waves execute sequentially; tasks within a wave can run in parallel.
5. **Validate plan (6-dimension check):**
   - **Spec coverage:** Every acceptance criterion maps to at least one task
   - **Task atomicity:** No task exceeds context window budget
   - **Dependency ordering:** No circular dependencies, waves are topologically sorted
   - **File scope:** No task touches more than 5 files
   - **Verification commands:** Every task criterion has a runnable check
   - **Context guard:** If plan has >8 tasks, warn the user and suggest splitting into multiple specs. >12 tasks = refuse and require split. (Large plans cause context rot even with fresh agents, because the orchestrator accumulates state.)
6. **Write state.** Save `.sdd/tasks.json`.

**Output:** `.sdd/tasks.json`

**Task schema:**

```json
{
  "version": 1,
  "spec_hash": "sha256:abc123...",
  "created_at": "2026-04-03T10:00:00Z",
  "waves": 3,
  "tasks": [
    {
      "id": 1,
      "title": "Short descriptive title",
      "description": "What to implement and why. Complete enough that a fresh agent can execute without guessing.",
      "files": ["src/auth/middleware.ts", "src/auth/middleware.test.ts"],
      "criteria": [
        "npm test -- middleware.test.ts exits 0",
        "middleware exports authGuard function"
      ],
      "deps": [],
      "wave": 1,
      "status": "pending",
      "cycles": 0,
      "started_at": null,
      "completed_at": null,
      "commit_sha": null,
      "blocked_reason": null
    }
  ]
}
```

**Failure modes:**
- Spec has BLOCKERs → Refuses to plan, reports blockers
- Task can't be made atomic (e.g., massive migration) → Reports to user with suggestion to simplify spec
- Circular dependency detected → Reports the cycle, asks user to resolve

**User interaction:** After writing tasks.json, prints the task table and asks for confirmation before proceeding. This is the "discuss" moment — the user can add/remove/reorder tasks.

---

### 4.3 `/zion:build` — Execute Tasks (The Loop)

**Purpose:** Execute tasks sequentially via fresh agents, building up the feature one verified commit at a time.

**Precondition:** `.sdd/tasks.json` exists with at least one `"pending"` task.

**Flags:**

| Flag | Behavior |
|------|----------|
| (none) | Full auto. Implements, verifies, commits each task. No stops. |
| `--safe` | Shows each task before executing. Waits for user OK. |
| `--dry` | Full auto but does NOT commit. Stages files only. User decides how to commit at the end. |
| `--pr` | Full auto + commits + creates GitHub PR at the end using build-log as description. |

Flags combine: `--dry --safe` = approve each task, no commits. `--safe --pr` = approve plan, then auto-build + PR.

**Phase 0: Branch Management**

Before the loop starts:
1. Check current branch with `git branch --show-current`
2. If on `main` or `master` → create and checkout feature branch: `feat/<spec-name>` (e.g. `feat/auth-middleware`)
3. If already on a feature branch → stay on it
4. This prevents accidental commits to main. Always.

**Phase 1: Resume Check**

1. Read `.sdd/tasks.json`
2. If tasks with status `"done"` exist → this is a **resume**. Skip completed tasks, report what was already done, continue from next pending.
3. Read `.sdd/learnings.md` for accumulated context.

**Phase 2: The Loop**

```
LOOP:
  1. Read .sdd/tasks.json
  2. Find next task: status == "pending" AND all deps have status == "done"
     - If none found AND blocked tasks exist → report and STOP
     - If none found AND all tasks done → exit loop, go to Phase 3
  3. --safe mode: show task details, wait for user approval
  4. Write .sdd/.active with task ID
  5. Spawn fresh Agent(task-executor) with context:
     - The task object from tasks.json
     - .sdd/learnings.md (accumulated knowledge)
     - Project type info (language, framework, test runner)
  6. Agent executes the task:
     a. Read learnings.md FIRST
     b. Read task description + existing code
     c. If task has testable criteria → write tests FIRST
     d. Implement the code
     e. Run tests / verification commands
     f. If pass → report DONE
     g. If fail → attempt fix (increment cycles)
     h. If cycles >= 3 → report BLOCKED with reason
  7. On DONE:
     - Stage specific files (never git add .)
     - Unless --dry: commit with message matching project convention (detected from git log)
       Fallback format: "feat(zion): [task title]"
     - Update task status to "done", set commit_sha (or "staged" if --dry)
     - Append learnings to .sdd/learnings.md
  8. On BLOCKED:
     - Update task status to "blocked", set blocked_reason
     - Append failure details to .sdd/learnings.md
  9. Delete .sdd/.active
  10. Update .sdd/build-log.json with timing and outcome
  11. GOTO LOOP
```

**Phase 3: Self-Review**

After all tasks complete (or all remaining are blocked):

1. Run `git diff main...HEAD` (or base branch) to see all changes
2. Review for **critical issues only**: security vulnerabilities, broken imports, obvious bugs
3. If critical issues found → fix, stage, commit as `fix(zion): resolve <issue>`, log the fix
4. Do NOT nitpick style or suggest improvements — only fix what would break or is unsafe

**Phase 4: Summary + PR**

1. Read `.sdd/build-log.json` for the full picture
2. Update learnings.md with a `## Project State` section at the top (2-3 lines summarizing what the project can do NOW — written for a future session that knows nothing about this run)
3. Print summary table to user
4. If `--dry`: list all staged files + suggest commit message(s)
5. If `--pr`: push branch and create PR:
   ```
   gh pr create --title "<spec goal, under 70 chars>" --body "<build-log summary>"
   ```
6. Archive completed spec: if all tasks done and verified, move `.sdd/` artifacts to `.sdd/archive/<spec-name>-<date>/`, keeping only `learnings.md` (carries forward)

**The learnings.md contract:**

```markdown
# Learnings

## Project State
[Updated after each /zion:build run. 2-3 lines describing what the project can do RIGHT NOW.
Written for a future agent or session that has zero context about previous runs.]

## Patterns
[Consolidated reusable knowledge — placed at TOP so every agent reads it first]
- Always use `IF NOT EXISTS` for migrations in this project
- The test helper at `test/helpers.ts` must be imported for DB setup

## Task Log
### Task 1: Setup project structure (DONE, 1 cycle)
- Detected Go 1.22 with standard library HTTP
- Used `internal/` directory convention from existing code

### Task 3: Token validation (BLOCKED, 3 cycles)
- Mock server times out after 5s — needs real Redis connection
- Tried: in-memory mock, testcontainers, direct connection — all fail on CI
```

**Key constraints:**
- **Fresh agent per task.** No conversation history carries between tasks. Only `learnings.md` and committed code persist.
- **Orchestrator never implements.** The main conversation only reads state, spawns agents, and updates status.
- **3-fix circuit breaker.** After 3 failed fix attempts, the task is blocked. No Fix #4 without user intervention. This prevents infinite loops.
- **Auto-commit per task** (unless `--dry`). Each completed task = one atomic commit. Clean, reviewable git history.
- **Never ask during execution.** The agent decides and documents in learnings.md. Stops only if truly ambiguous (conflicting requirements).
- **Branch safety.** Never commits to main/master. Auto-creates feature branch if needed.

**Failure modes:**
- Agent reports TASK_GAP (spec is unclear) → Task paused, user notified with specific gap
- All remaining tasks are blocked → Build stops, summary shows all blockers
- Agent produces code but tests don't pass after 3 cycles → Blocked, learnings capture what was tried

---

### 4.4 `/zion:verify` — Verify Against Spec

**Purpose:** Independently verify that the implementation meets the spec's acceptance criteria, using 4 levels of verification depth.

**Precondition:** At least one task in `.sdd/tasks.json` has status "done".

**Process:**

1. **Collect criteria.** Read all acceptance criteria from:
   - `.sdd/TECH_SPEC.md` (spec-level criteria)
   - `.sdd/tasks.json` (per-task criteria)
   - Deduplicate (task criteria that implement spec criteria)

2. **Auto-detect test runner.** Based on project type:
   - Node: `npm test` / `yarn test` / `pnpm test`
   - Go: `go test ./...`
   - Python: `pytest` / `python -m pytest`
   - Rust: `cargo test`
   - Other: read from `.sdd/config.json` if present

3. **Run test suite.** Execute the project's tests and capture results.

4. **Verify each criterion at 4 levels** (inspired by GSD):

   | Level | Check | How |
   |-------|-------|-----|
   | **Exists** | File/function/route is present | Glob for file, Grep for function/export |
   | **Substantive** | Real implementation, not a stub or placeholder | Grep for TODO/FIXME/placeholder patterns, check function body length > trivial |
   | **Wired** | Connected to the rest of the system | Grep for imports/requires of the file, check route registration, verify exports are consumed |
   | **Functional** | Actually works when invoked | Run the specific test or command from the criterion |

5. **Write results.** Save `.sdd/verify-state.json`:

```json
{
  "version": 1,
  "spec_hash": "sha256:abc123...",
  "verified_at": "2026-04-03T12:00:00Z",
  "test_runner": "npm test",
  "test_result": "pass",
  "criteria": [
    {
      "source": "spec:1",
      "criterion": "GET /health returns 200",
      "command": "curl -s -o /dev/null -w '%{http_code}' localhost:8080/health",
      "levels": {
        "exists": { "pass": true, "evidence": "src/routes/health.ts exists" },
        "substantive": { "pass": true, "evidence": "handler function has 12 lines, returns JSON response" },
        "wired": { "pass": true, "evidence": "imported in src/routes/index.ts line 14, registered at line 28" },
        "functional": { "pass": true, "evidence": "test health.test.ts passes (GET /health → 200 OK)" }
      },
      "status": "pass"
    },
    {
      "source": "task:3",
      "criterion": "Token validation rejects expired tokens",
      "command": "npm test -- token.test.ts",
      "levels": {
        "exists": { "pass": true, "evidence": "src/auth/token.ts exists" },
        "substantive": { "pass": true, "evidence": "validateToken() has 24 lines with expiry check" },
        "wired": { "pass": true, "evidence": "imported in middleware.ts line 5" },
        "functional": { "pass": false, "evidence": "token.test.ts FAIL: test_expired_token timeout after 5s" }
      },
      "status": "fail"
    }
  ],
  "summary": {
    "total": 12,
    "pass": 10,
    "fail": 2,
    "pass_rate": "83%"
  }
}
```

6. **Print summary.**

```
VERIFICATION: auth-middleware
──────────────────────────────────
12 criteria | 10 pass | 2 fail (83%)

PASS  GET /health returns 200                    ████ exists ✓ substantive ✓ wired ✓ functional ✓
PASS  Auth middleware blocks unauthenticated      ████ exists ✓ substantive ✓ wired ✓ functional ✓
FAIL  Token validation rejects expired tokens     ███░ exists ✓ substantive ✓ wired ✓ functional ✗
FAIL  Rate limiter caps at 100 req/min           ██░░ exists ✓ substantive ✓ wired ✗ functional ✗

FAILURES:
  #3 token-validation: test_expired_token timeout (5s) — see task #3 blocked reason
  #7 rate-limiter: rate_limiter.ts not imported anywhere — wired check failed
```

---

### 4.5 `/zion:status` — Progress Dashboard

**Purpose:** Show a quick, scannable overview of the current SDD state. Works at any point in the workflow.

**Precondition:** None. Works with partial state (shows what's available).

**Output format:**

```
ZION STATUS
═══════════════════════════════════════════════════════

SPEC: auth-middleware (ready)                    hash: abc123
PLAN: 8 tasks | 3 waves                         created: 2026-04-03
BUILD: 5/8 done | 1 blocked | 2 pending          elapsed: 12m
VERIFY: 10/12 pass (83%)                         last: 2026-04-03 12:00

Wave  Task                        Status     Cycles  Time
───────────────────────────────────────────────────────────
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

LEARNINGS: 4 patterns, 8 task entries
```

---

## 5. Agents

### 5.1 `spec-writer`

| Field | Value |
|-------|-------|
| Model | opus |
| Tools | Read, Write, Bash, Glob, Grep, WebFetch |
| Memory | project |
| Purpose | Requirements → TECH_SPEC.md |

**System prompt core principles:**
- Read codebase BEFORE writing anything
- Every criterion must be a runnable command or testable assertion
- No TBD/TODO/placeholder — fill it or declare a BLOCKER
- Self-validate against the spec-contract rule before declaring ready
- If the user's request is unclear, ask questions — don't guess

**Anti-rationalization table:**

| You might think... | Why it's wrong | Do this instead |
|---|---|---|
| "The builder will figure out the details" | Builder follows spec literally, no judgment calls | Be explicit in every section |
| "Standard pattern, no need to detail" | Standard where? Every project is different | Grep the codebase to confirm |
| "Nice to have, I'll add it" | Out of scope unless user specified | Move to Out of Scope |
| "This is too simple for a full spec" | Simple features have edge cases too | Write the spec, keep it short |
| "I'll skip Out of Scope, everything is obvious" | Explicit boundaries prevent scope creep | Always fill Out of Scope |

### 5.2 `task-executor`

| Field | Value |
|-------|-------|
| Model | sonnet |
| Tools | Read, Write, Edit, Bash, Glob, Grep |
| Memory | project |
| Purpose | Task → implemented + tested + committed code |

**System prompt core principles:**
- Read `learnings.md` FIRST before any implementation
- Write tests before code when the task has testable criteria
- Max 3 fix cycles, then STOP and report BLOCKED with full context
- Report TASK_GAP immediately if the spec is unclear — never guess
- Never refactor beyond task scope — log observations to learnings.md
- Never do design work — you implement, you don't architect

**Anti-rationalization table:**

| You might think... | Why it's wrong | Do this instead |
|---|---|---|
| "Close enough, the test almost passes" | Almost ≠ passes. 0 or 1. | Run the test, report the actual result |
| "I'll refactor this while I'm here" | Out of task scope, risks breaking other things | Log to learnings.md for a future task |
| "The spec probably meant..." | Guessing = bugs. You are not the spec-writer. | Report TASK_GAP, stop, let user clarify |
| "This dependency is outdated, I'll update it" | Scope creep. Version changes cascade. | Log it. Only if it blocks THIS task's tests. |
| "I'll skip the test, the code clearly works" | Code that works without a test is unverified code | Write the test. Always. |
| "3 cycles is too strict, one more try" | Cycle 4 usually repeats cycle 3. Fresh eyes needed. | BLOCKED. Log what you tried. |

---

## 6. Hooks

### 6.1 `bootstrap.sh` — SessionStart

**Purpose:** When a session starts in a project that has `.sdd/` state, automatically inject context about where things stand.

**Behavior:**
1. Check if `.sdd/` directory exists in the current working directory
2. If no → exit 0 (nothing to inject)
3. If yes → read state files and output a summary as `additionalContext`:
   - Spec status (ready/draft/missing)
   - Task progress (X/Y done, Z blocked)
   - Active task (if `.active` exists)
   - Last verification result

**Output format (JSON on stdout):**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Zion SDD active: spec 'auth-middleware' ready, 5/8 tasks done, 1 blocked (#4 token-validation), verification 83%. Run /zion:status for details."
  }
}
```

### 6.2 `verify-gate.sh` — Stop

**Purpose:** Prevent the agent from completing a session with incomplete SDD work.

**Behavior:**
1. If `.sdd/` doesn't exist → exit 0 (not an SDD project, don't enforce)
2. If `.sdd/.active` exists → exit 2 with reason "Task #X is in progress. Complete it or mark it blocked before ending."
3. If all tasks in `tasks.json` have status "done" AND `verify-state.json` doesn't exist → exit 2 with reason "All tasks done but unverified. Run /zion:verify."
4. If `verify-state.json` exists with failures → exit 0 but output warning (don't block, but inform)
5. Otherwise → exit 0

**Why not block on verification failures?** Because some failures may be intentional (known issues, deferred work). The user decides whether to re-run verify or accept. But starting verify is not optional — that's enforced.

---

## 7. Rules

### 7.1 `spec-contract.md`

Defines the TECH_SPEC.md format contract. Loaded as context when `spec-writer` runs.

**Key rules:**
- All 6 sections are mandatory (Goal, Constraints, Acceptance Criteria, Architecture, Edge Cases, Out of Scope)
- Acceptance Criteria must have a verification command after each criterion
- Architecture must list every file to create AND modify
- File paths must be relative to project root
- No prose without purpose — every sentence either constrains or specifies

### 7.2 `execution-protocol.md`

Defines task execution rules. Loaded as context when `task-executor` runs.

**Key rules:**
- Read `learnings.md` before starting any work
- Test-first when criteria are testable
- Max 3 fix cycles (circuit breaker)
- Report TASK_GAP if spec is ambiguous
- One task = one commit. Message format: `feat(zion): [task title]`
- Append to `learnings.md` after every task (patterns section for reusable knowledge, task log for specifics)
- Never modify files outside the task's `files` list unless absolutely necessary (and log why)

---

## 8. State Directory (`.sdd/`)

### 8.1 Directory structure

```
.sdd/
├── TECH_SPEC.md           # The specification
├── tasks.json             # Task list with status, waves, dependencies
├── learnings.md           # Append-only cross-task knowledge (survives archives)
├── spec-state.json        # Spec validation metadata
├── verify-state.json      # 4-level verification results
├── build-log.json         # Per-task timing, cycles, outcomes
├── config.json            # Optional overrides (test runner, etc.)
├── .active                # Ephemeral: current task ID
├── .gitignore             # Ignores .active only
└── archive/               # Completed specs (moved here after all tasks done + verified)
    └── auth-middleware-2026-04-03/
        ├── TECH_SPEC.md
        ├── tasks.json
        ├── verify-state.json
        └── build-log.json
```

### 8.2 Git strategy

Most `.sdd/` files are **committable**. This is intentional:
- `TECH_SPEC.md` is documentation — it should be in the repo
- `tasks.json` is a work log — useful for team visibility and post-mortems
- `learnings.md` is institutional knowledge — accumulates value over time
- `verify-state.json` is evidence — proves the feature was verified

Only `.active` is gitignored (ephemeral session state).

### 8.3 Archive strategy

When a spec is fully built and verified, `/zion:build` (Phase 4) moves all spec-specific artifacts to `.sdd/archive/<spec-name>-<date>/`. Only `learnings.md` stays at root — it carries forward across specs, accumulating project-wide knowledge.

This means `.sdd/` is always clean for the next spec, but history is preserved and searchable.

### 8.4 Lifecycle

```
/zion:spec  → creates TECH_SPEC.md, spec-state.json
/zion:plan  → creates tasks.json
/zion:build → creates .active (per task), updates tasks.json, appends learnings.md, creates build-log.json
/zion:verify → creates verify-state.json
/zion:status → reads all, writes nothing
```

---

## 9. Plugin File Structure

```
zion-core/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── spec/
│   │   └── SKILL.md
│   ├── plan/
│   │   └── SKILL.md
│   ├── build/
│   │   └── SKILL.md
│   ├── verify/
│   │   └── SKILL.md
│   └── status/
│       └── SKILL.md
├── agents/
│   ├── spec-writer.md
│   └── task-executor.md
├── hooks/
│   ├── hooks.json
│   ├── bootstrap.sh
│   └── verify-gate.sh
├── rules/
│   ├── spec-contract.md
│   └── execution-protocol.md
├── templates/
│   ├── TECH_SPEC.template.md
│   └── task.template.json
└── README.md
```

---

## 10. Competitive Analysis

| Feature | SuperPowers | Ralph Loop | GSD | **Zion** |
|---------|-------------|------------|-----|----------|
| Commands | 14 | 2 | 44 | **5** |
| Agents per task | 3 | 1 | 1 | **1** |
| Quality gates | Suggest | None | Check | **BLOCK** |
| Verification depth | Tests + review | Tests only | 4-level | **4-level + self-review** |
| Visual QA | No | No | No | **zion-vision ext** |
| Context isolation | Subagents | Fresh loop | Fresh agents | **Fresh agents** |
| Token efficiency | Heavy | Light | Medium | **Light** |
| State persistence | Files | JSON + txt | Markdown | **JSON + MD** |
| Learning persistence | None | progress.txt | STATE.md | **learnings.md (project-wide, carries across specs)** |
| Parallel execution | No | No | Waves | **Waves** |
| Session survival | Partial | Yes | Yes | **Yes (resume from tasks.json)** |
| Branch safety | No | Yes | No | **Yes (auto-create feature branch)** |
| Build modes | No | No | `--auto` | **`--dry`, `--safe`, `--pr`** |
| Context guard | No | Story sizing | No | **>8 tasks = warn, >12 = refuse** |
| Spec archiving | No | Archive prd.json | No | **`.sdd/archive/` with learnings carry-forward** |
| Self-review | 2-stage review | No | Verifier | **git diff critical-only** |
| Install complexity | Plugin | Bash script | npm install | **Plugin** |

---

## 11. Success Criteria

### 11.1 Plugin loads correctly
- `claude --plugin-dir ~/Developer/zion-core` starts without errors
- All 5 commands appear in `/` autocomplete as `zion:*`
- Hooks register (SessionStart, Stop)

### 11.2 End-to-end on a sample project
- `/zion:spec "Build a CLI tool that converts CSV to JSON"` → produces valid TECH_SPEC.md
- `/zion:plan` → produces tasks.json with waves and dependencies
- `/zion:build` → executes tasks, commits code, updates state
- `/zion:verify` → runs 4-level checks, produces verify-state.json
- `/zion:status` → shows accurate dashboard at every step

### 11.3 Quality gates work
- Trying to end session with `.active` present → blocked
- Trying to end session with all tasks done but no verify → blocked
- Stop hook allows exit when no `.sdd/` exists

### 11.4 Context isolation works
- Each task-executor agent has no memory of previous tasks (only learnings.md)
- Learnings from task N are available to task N+1

### 11.5 Circuit breaker works
- A task that fails 3 times → marked blocked, not retried
- Blocked reason is specific and actionable

---

## 12. Implementation Phases

### Phase 1: Skeleton (Day 1)
- Directory structure + plugin.json
- Agent definitions (spec-writer.md, task-executor.md)
- Empty skill files with correct frontmatter

### Phase 2: Core Skills (Day 2-3)
- `/zion:spec` skill — full flow with spec-writer delegation
- `/zion:plan` skill — decomposition + wave assignment
- `/zion:status` skill — state reader

### Phase 3: Execution Loop (Day 3-4)
- `/zion:build` skill — the Ralph Loop with fresh agents
- Task-executor agent system prompt
- learnings.md contract

### Phase 4: Verification + Hooks (Day 4-5)
- `/zion:verify` skill — 4-level depth checks
- `verify-gate.sh` — Stop hook enforcement
- `bootstrap.sh` — SessionStart context injection

### Phase 5: Test + Iterate (Day 5+)
- Test on a real project (not Shopify)
- Fix issues found during testing
- Polish skill prompts based on actual agent behavior

---

## 13. Permission Model

Zion does NOT manage permissions itself. It relies on Claude Code's native permission modes.

### Recommended setup

| Use case | Permission mode | How to enable |
|----------|----------------|---------------|
| **Full auto (recommended)** | `auto` | `claude --enable-auto-mode` or `Shift+Tab` to cycle to auto |
| **Review each task** | `acceptEdits` | `Shift+Tab` once from default |
| **Manual approval** | `default` | Default behavior, no flags needed |
| **CI/headless** | `dontAsk` + allow rules | `claude --permission-mode dontAsk` with pre-configured `permissions.allow` |

### How auto mode works with Zion

- Auto mode uses a classifier model that reviews each action before execution — no prompts
- The classifier checks subagent work at 3 points: spawn, during execution, and on return
- `permissionMode` in agent frontmatter is **ignored** when auto mode is active (classifier takes over)
- Local file ops in working directory are auto-approved
- Shell commands go through the classifier
- If the classifier blocks 3 consecutive actions, auto mode pauses and prompts

### What Zion's `allowed-tools` in skill frontmatter does

Each skill declares its tool needs. This works as a **baseline** in non-auto modes — Claude won't prompt for these tools when the skill is active:

```yaml
# skills/build/SKILL.md
---
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---
```

```yaml
# skills/status/SKILL.md
---
allowed-tools: Read, Glob
---
```

In auto mode, `allowed-tools` is redundant (classifier handles everything). In default/acceptEdits mode, it reduces prompt fatigue for the specific tools each skill needs.

### What Zion does NOT do

- No `--dangerously-skip-permissions` recommendation (unsafe, unnecessary with auto mode)
- No blanket `Bash(*)` in plugin settings (auto mode drops these anyway)
- No `permissionMode: bypassPermissions` in agent definitions (auto mode ignores it)

---

## 14. Future Extensions

- **zion-vision:** Visual QA with computed-style verification (separate plugin)
- **Wave parallelism:** Execute independent tasks in parallel using worktrees
- **Custom agents:** Allow projects to define domain-specific agents via `.sdd/agents/`
- **Marketplace publishing:** Submit to Claude Code plugin marketplace
- **CI integration:** Hook into GitHub Actions for automated verify on PR
