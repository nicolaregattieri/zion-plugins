#!/bin/bash
# bootstrap.sh — SessionStart hook
# Injects SDD context when a session starts in a project with .sdd/ state.
# Stdout becomes additionalContext in Claude's conversation.

# Not an SDD project → exit silently
if [ ! -d ".sdd" ]; then
  exit 0
fi

# Build context summary
OUTPUT="Zion SDD active"

# Spec status
if [ -f ".sdd/spec-state.json" ]; then
  FEATURE=$(jq -r '.feature // "unknown"' .sdd/spec-state.json 2>/dev/null)
  STATUS=$(jq -r '.status // "unknown"' .sdd/spec-state.json 2>/dev/null)
  OUTPUT="$OUTPUT: spec '$FEATURE' ($STATUS)"
fi

# Task progress
if [ -f ".sdd/tasks.json" ]; then
  TOTAL=$(jq '.tasks | length' .sdd/tasks.json 2>/dev/null) || TOTAL=0
  DONE=$(jq '[.tasks[] | select(.status == "done")] | length' .sdd/tasks.json 2>/dev/null) || DONE=0
  BLOCKED=$(jq '[.tasks[] | select(.status == "blocked")] | length' .sdd/tasks.json 2>/dev/null) || BLOCKED=0
  PENDING=$(jq '[.tasks[] | select(.status == "pending")] | length' .sdd/tasks.json 2>/dev/null) || PENDING=0
  # Fallback for empty jq output
  : "${TOTAL:=0}" "${DONE:=0}" "${BLOCKED:=0}" "${PENDING:=0}"
  OUTPUT="$OUTPUT, ${DONE}/${TOTAL} tasks done"
  if [ "$BLOCKED" -gt 0 ] 2>/dev/null; then
    OUTPUT="$OUTPUT ($BLOCKED blocked)"
  fi
fi

# Active task
if [ -f ".sdd/.active" ]; then
  ACTIVE_ID=$(cat .sdd/.active)
  OUTPUT="$OUTPUT, task #$ACTIVE_ID in progress"
fi

# Verification
if [ -f ".sdd/verify-state.json" ]; then
  PASS_RATE=$(jq -r '.summary.pass_rate // "unknown"' .sdd/verify-state.json 2>/dev/null)
  OUTPUT="$OUTPUT, verify $PASS_RATE"
fi

OUTPUT="$OUTPUT. Run /zion:status for details."

echo "$OUTPUT"
exit 0
