# Zion Core

Spec-Driven Development plugin for Claude Code. From idea to verified code with zero waste.

## Commands

### `/zion:spec` — Specify

Transforms your intent into a precise, machine-readable specification.

```
/zion:spec "Add rate limiting to the API — max 100 req/min per IP"
/zion:spec https://docs.stripe.com/webhooks      # from documentation URL
/zion:spec src/auth/middleware.ts                  # extend existing code
```

What happens:
1. Detects project type (language, framework, test runner) from root files
2. Reads codebase patterns via Glob/Grep (naming, imports, directory structure)
3. Delegates to **spec-writer agent** (opus, 30 turns) with full project context
4. Agent writes `.sdd/TECH_SPEC.md` with 8 mandatory sections
5. Validates spec via `zion-validate-spec` — no TBD, no vague criteria, every AC has a verification command
6. Writes `.sdd/spec-state.json` with status `ready`

**Spec sections:** Goal, Constraints, Reuse, Acceptance Criteria, Architecture, Edge Cases, Out of Scope, Builder Notes.

### `/zion:plan` — Plan

Decomposes the spec into ordered, atomic tasks grouped in waves.

```
/zion:plan
```

**Precondition:** spec must be `ready`.

What happens:
1. Breaks spec into tasks — each touches max 5 files, fits in one agent context
2. Builds dependency graph, groups independent tasks into waves
3. Context guard: >8 tasks = warning, >12 tasks = refuses (split the spec)
4. Presents task table — you approve before proceeding

### `/zion:build` — Build

Executes tasks via fresh agents. One task, one agent, one commit.

```
/zion:build              # full auto — implement, test, commit
/zion:build --safe       # show each task, wait for your OK
/zion:build --dry        # full auto but no commits — stages files only
/zion:build --pr         # full auto + commits + creates GitHub PR
```

Flags combine: `--safe --pr` = approve each task, then auto-PR.

What happens:
1. Creates `feat/<feature-name>` branch if on main/master
2. Resumes from previous session if tasks already done
3. For each task: spawns fresh **task-executor agent** (sonnet, 25 turns)
4. Agent reads `learnings.md` first, then implements test-first
5. On pass: stages, commits, marks done. On fail: retries up to 3 cycles, then blocked.
6. After all tasks: self-review, auto-verify, auto-fix if needed

**Circuit breaker:** 3 failed fix cycles = task blocked. No infinite loops.

### `/zion:verify` — Verify

Independently verifies implementation against the spec. Numbers, not vibes.

```
/zion:verify
```

**4-level depth per criterion:**

| Level | What | How |
|-------|------|-----|
| **Exists** | File/function/route present | Glob, Grep |
| **Substantive** | Real code, not a stub | Check for TODO/FIXME, function body length |
| **Wired** | Connected to the system | Grep imports, route registration |
| **Functional** | Actually works | Run the verification command from spec |

### `/zion:fix` — Fix

Diagnoses and fixes verification failures or blocked tasks.

```
/zion:fix                        # auto — fix all verify failures
/zion:fix "auth rejects tokens"  # manual — fix specific bug
/zion:fix --task 4               # retry blocked task with fresh context
```

What happens:
1. Reads failures from `verify-state.json` (or your bug description)
2. Spawns diagnostic agent — finds root cause before touching code
3. Creates targeted fix tasks, executes with fresh agents
4. Re-verifies only the affected criteria

### `/zion:status` — Status

Dashboard of current SDD state. Works at any point, with partial state.

```
/zion:status
```

## Architecture

```
zion-core/
├── .claude-plugin/plugin.json       # Plugin metadata
├── skills/                          # 6 commands (spec, plan, build, verify, fix, status)
├── agents/
│   ├── spec-writer.md               # Opus — requirements → TECH_SPEC.md
│   └── task-executor.md             # Sonnet — task → implemented + tested code
├── hooks/
│   ├── hooks.json                   # PreToolUse (Bash, Read), SessionStart, Stop
│   ├── safe-bash.sh                 # Bash command allow/deny list
│   ├── safe-read.sh                 # Block Read(.env*), Read(settings.local.json)
│   ├── bootstrap.sh                 # SessionStart — inject SDD context
│   └── verify-gate.sh               # Stop — block incomplete work
├── rules/
│   ├── spec-contract.md             # 8-section spec format contract
│   ├── execution-protocol.md        # 3-cycle circuit breaker, test-first, learnings
│   └── env-security.md              # Never read .env files, use $VAR only
├── bin/
│   ├── zion-validate-spec           # Validates TECH_SPEC.md structure
│   └── zion-parse-flags             # Parses --safe, --dry, --pr flags
└── templates/
    ├── TECH_SPEC.template.md        # Spec template (8 sections)
    └── task.template.json           # Task schema (waves, deps, status)
```

## State Directory

All state lives in `.sdd/` at the project root. Created by `/zion:spec`, updated by each command.

```
.sdd/
├── TECH_SPEC.md        # The specification (committable)
├── tasks.json          # Tasks with waves, deps, status (committable)
├── learnings.md        # Cross-task knowledge (committable, persists across specs)
├── spec-state.json     # Spec validation metadata
├── verify-state.json   # 4-level verification results
├── build-log.json      # Per-task timing and outcomes
├── .active             # Current task marker (gitignored)
└── archive/            # Completed specs moved here after full verification
```

**Session survival:** close Claude, reopen, run `/zion:build` — resumes from where it stopped.

## Hooks

| Hook | Event | Behavior |
|------|-------|----------|
| `safe-bash.sh` | PreToolUse (Bash) | Auto-approve safe commands, deny dangerous ones + .env reads |
| `safe-read.sh` | PreToolUse (Read) | Block reading .env files and settings.local.json |
| `bootstrap.sh` | SessionStart | Inject SDD progress summary into context if `.sdd/` exists |
| `verify-gate.sh` | Stop | Block session exit if task in-progress or work unverified |

## Security

See [env-security rule](rules/env-security.md). Two enforcement layers:

1. **Hooks** — `safe-bash.sh` and `safe-read.sh` block .env reads at the tool level
2. **Rules** — `env-security.md` teaches agents to use `$VAR` in Bash, never read files directly

Secrets stay in the shell process. They never enter the conversation context.
