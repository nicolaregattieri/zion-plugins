#!/bin/bash
# verify-gate.sh — Stop hook (blocking)
# Prevents the agent from completing with incomplete SDD work.
# Exit 2 = BLOCK with reason on stderr.
# Adapted from ai-shopify-plan's vision-stop-gate.sh pattern.

INPUT=$(cat)

# CRITICAL: Prevent infinite loop.
# If the stop hook already triggered and Claude continued, allow it to stop this time.
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

# Not an SDD project → allow stop
if [ ! -d ".sdd" ]; then
  exit 0
fi

# No tasks file → spec phase only, allow stop
if [ ! -f ".sdd/tasks.json" ]; then
  exit 0
fi

# Task in progress → BLOCK
if [ -f ".sdd/.active" ]; then
  TASK_ID=$(cat .sdd/.active)
  echo "Zion: Task #$TASK_ID is in progress. Complete it or mark it blocked before stopping." >&2
  exit 2
fi

# Check task statuses
TOTAL=$(jq '.tasks | length' .sdd/tasks.json 2>/dev/null || echo 0)
DONE=$(jq '[.tasks[] | select(.status == "done")] | length' .sdd/tasks.json 2>/dev/null || echo 0)
BLOCKED=$(jq '[.tasks[] | select(.status == "blocked")] | length' .sdd/tasks.json 2>/dev/null || echo 0)
PENDING=$(jq '[.tasks[] | select(.status == "pending")] | length' .sdd/tasks.json 2>/dev/null || echo 0)

# All tasks done (or done+blocked) but no verification → BLOCK
if [ "$PENDING" -eq 0 ] && [ "$DONE" -gt 0 ] && [ ! -f ".sdd/verify-state.json" ]; then
  echo "Zion: All tasks complete but unverified. Run /zion:verify before stopping." >&2
  exit 2
fi

# Verification exists with failures → WARN (don't block)
if [ -f ".sdd/verify-state.json" ]; then
  FAILURES=$(jq '.summary.fail // 0' .sdd/verify-state.json 2>/dev/null || echo 0)
  if [ "$FAILURES" -gt 0 ]; then
    PASS_RATE=$(jq -r '.summary.pass_rate // "?"' .sdd/verify-state.json 2>/dev/null)
    echo "Zion: Warning — $FAILURES verification failure(s) ($PASS_RATE pass rate). Consider re-running /zion:verify."
    # Don't block — user may accept known failures
  fi
fi

exit 0
