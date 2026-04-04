#!/bin/bash
# vision-bootstrap.sh — SessionStart hook
# Injects Zion Vision context when a session starts in a project with .sdd/ state.
# Stdout becomes additionalContext in Claude's conversation.

# Not a Vision project → exit silently
if [ ! -d ".sdd" ]; then
  exit 0
fi

# No vision-spec.json → nothing to report
if [ ! -f ".sdd/vision-spec.json" ]; then
  exit 0
fi

# Read spec and compute summary
TOTAL=$(jq '.comparisons | length' .sdd/vision-spec.json 2>/dev/null || echo 0)
PASS=$(jq '[.comparisons[] | select(.result == "pass")] | length' .sdd/vision-spec.json 2>/dev/null || echo 0)
FAIL=$(jq '[.comparisons[] | select(.result == "fail")] | length' .sdd/vision-spec.json 2>/dev/null || echo 0)
PENDING=$(jq '[.comparisons[] | select(.result == null)] | length' .sdd/vision-spec.json 2>/dev/null || echo 0)

# Compute overall fidelity (pass / total * 100, or 0 if no comparisons)
if [ "$TOTAL" -gt 0 ] 2>/dev/null; then
  FIDELITY=$(( PASS * 100 / TOTAL ))
else
  FIDELITY=0
fi

echo "Zion Vision active: ${TOTAL} comparisons (${PASS} pass, ${FAIL} fail, ${PENDING} pending), fidelity ${FIDELITY}%. Run /zion-vision:status for details."

exit 0
