# Zion Core

Spec-Driven Development plugin for Claude Code. From idea to verified code with zero waste.

## Commands

| Command | Purpose |
|---------|---------|
| `/zion:spec` | Generate TECH_SPEC.md from requirements (includes research) |
| `/zion:plan` | Break spec into wave-based tasks |
| `/zion:build` | Execute tasks via fresh-agent loop |
| `/zion:verify` | 4-level verification against spec |
| `/zion:status` | Progress dashboard |

## Architecture

```
User describes feature
    |
    v
/zion:spec ---- spec-writer agent (opus) ----> .sdd/TECH_SPEC.md
    |
    v
/zion:plan ---- orchestrator ----------------> .sdd/tasks.json (waves)
    |
    v
/zion:build --- task-executor agent (sonnet) -> code + commits
    |           (fresh context per task,
    |            3-fix circuit breaker,
    |            append-only learnings)
    v
/zion:verify -- orchestrator ----------------> .sdd/verify-state.json
                (exists > substantive >
                 wired > functional)
```

## Key Principles

- **5 commands, that's it.** Research is inside spec. Discuss is inside plan. No bloat.
- **Quality gates BLOCK.** Hooks exit non-zero. The agent cannot finish without meeting criteria.
- **Fresh context per task.** Each task gets a new agent. No context rot.
- **Append-only learnings.** Knowledge accumulates across tasks and sessions.
- **Wave-based parallelism.** Independent tasks can run concurrently.
- **4-level verification.** Exists > Substantive > Wired > Functional. No stubs pass.

## State

All state lives in `.sdd/` at project root:

```
.sdd/
  TECH_SPEC.md        # The spec (committable)
  tasks.json          # Tasks with waves and status (committable)
  learnings.md        # Append-only knowledge log (committable)
  spec-state.json     # Validation state
  verify-state.json   # Verification results
  build-log.json      # Per-task timing
  .active             # Current task marker (gitignored)
```

## Install

```bash
claude --plugin-dir ~/Developer/zion-core
```

## Related

- **zion-vision** — Extends core with visual QA (computed-style verification, screenshot comparison)
