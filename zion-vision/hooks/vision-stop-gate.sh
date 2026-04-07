#!/bin/bash
# vision-stop-gate.sh — Stop hook (blocking)
# Prevents the agent from stopping when vision comparisons are incomplete or unmeasured.
# Exit 2 = BLOCK with reason on stderr.

INPUT=$(cat)

# CRITICAL: Prevent infinite loop.
# If stop hook already triggered and Claude continued, allow it to stop this time.
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

# Not a Vision project → allow stop
if [ ! -d ".sdd" ]; then
  exit 0
fi

# No vision-spec.json → allow stop
if [ ! -f ".sdd/vision-spec.json" ]; then
  exit 0
fi

# Condition (a): any comparison with result: null → BLOCK
NULL_COUNT=$(jq '[.comparisons[] | select(.result == null)] | length' .sdd/vision-spec.json 2>/dev/null || echo 0)
if [ "$NULL_COUNT" -gt 0 ] 2>/dev/null; then
  echo "Vision: ${NULL_COUNT} comparison(s) not measured yet. Run /zion-vision:compare." >&2
  exit 2
fi

# Condition (b): any comparison result without computed_values key → BLOCK
TOTAL=$(jq '.comparisons | length' .sdd/vision-spec.json 2>/dev/null || echo 0)
NO_CV_COUNT=$(jq '[.comparisons[] | select(.result | has("computed_values") | not)] | length' .sdd/vision-spec.json 2>/dev/null || echo 0)
if [ "$NO_CV_COUNT" -gt 0 ] 2>/dev/null; then
  # Find the name of the first comparison whose result is missing computed_values
  FIRST_NAME=$(jq -r '[.comparisons[] | select(.result | has("computed_values") | not)][0].name // "unknown"' .sdd/vision-spec.json 2>/dev/null)
  echo "Vision: comparison '${FIRST_NAME}' has no computed_values. Re-run with Playwright measurement." >&2
  exit 2
fi

# Condition (c): computed_values exists but NO numeric measurements (digits + px/rem/%/rgb())
# Check each comparison for numeric values
: "${TOTAL:=0}"
if ! [ "$TOTAL" -gt 0 ] 2>/dev/null; then
  # Can't read comparisons count — allow stop rather than block on corrupt file
  exit 0
fi
BAD_NAME=""
IDX=0
while [ "$IDX" -lt "$TOTAL" ]; do
  CV=$(jq -r ".comparisons[$IDX].result.computed_values | to_entries[] | .value | tostring" .sdd/vision-spec.json 2>/dev/null)
  # Check if any value matches numeric pattern: digits followed by px, rem, %, or rgb(
  if ! echo "$CV" | grep -qE '[0-9]+(px|rem|%)|rgb\('; then
    BAD_NAME=$(jq -r ".comparisons[$IDX].name // \"unknown\"" .sdd/vision-spec.json 2>/dev/null)
    echo "Vision: comparison '${BAD_NAME}' has no numeric measurements. Categorical matches like 'looks good' are rejected." >&2
    exit 2
  fi
  IDX=$(( IDX + 1 ))
done

# Condition (e): warn if any comparison has status 'fail' (non-blocking)
FAIL_COUNT=$(jq '[.comparisons[] | select(.result.status == "fail")] | length' .sdd/vision-spec.json 2>/dev/null || echo 0)
if [ "$FAIL_COUNT" -gt 0 ] 2>/dev/null; then
  echo "Vision: Warning — ${FAIL_COUNT} comparison(s) have status 'fail'. Review before finalizing."
fi

# Condition (d): all comparisons valid with numeric values → allow stop
exit 0
