# Execution Protocol — Task Execution Rules

This rule governs how tasks are executed in the Zion SDD build loop. It applies to every task-executor agent instance.

## Execution Order (Non-Negotiable)

1. Read `.sdd/learnings.md` — FIRST, before anything else
2. Read the task description and criteria
3. Read existing code in the task's file list
4. Write tests (when criteria are testable)
5. Implement
6. Run tests
7. Pass → DONE. Fail → fix (max 3 cycles). Still failing → BLOCKED.

## Circuit Breaker: 3 Cycles

- **Cycle 1**: Implement + test
- **Cycle 2**: First fix based on error output
- **Cycle 3**: Second fix — final attempt

After 3 cycles: STOP. Report BLOCKED with what you tried and the exact error. No cycle 4. Ever.

## TASK_GAP Protocol

If the spec is ambiguous or contradictory: report TASK_GAP immediately. Do not guess intent. Do not interpret. Do not "probably meant". Stop and report what needs clarification.

## Commit Convention

One task = one commit. Format:
```
feat(zion): [task title]
```

Stage specific files only. Never `git add .` or `git add -A`.

## Learnings Contract

After EVERY task (DONE or BLOCKED), append to `.sdd/learnings.md`:
- Task number, title, outcome, cycles used
- What was learned (patterns, pitfalls, codebase quirks)
- Reusable patterns go in the `## Patterns` section at the top

## Scope Rules

- Only modify files in the task's `files` list
- If you must touch another file, log WHY in learnings.md
- Never refactor beyond task scope
- Never update dependencies unless they block the current task's tests
- Never do design work — implement only

## Anti-Rationalization

| You might think... | Why it's wrong | Do this instead |
|---|---|---|
| "This blocks me but it's not in my files list" | The plan scoped your task. Respect it. | Log why you need the file. Fix minimally. |
| "Tests are slow, I'll skip this run" | Unverified code is unfinished code | Run them. Every time. |
| "I know what the spec means" | If it's ambiguous, you're guessing | TASK_GAP. Let the user clarify. |
| "One more try past cycle 3" | Cycle 4 repeats cycle 3. Diminishing returns. | BLOCKED. Fresh eyes needed. |
| "I'll clean up this code while I'm here" | Scope creep breaks other tasks | Log it in learnings.md for later |
