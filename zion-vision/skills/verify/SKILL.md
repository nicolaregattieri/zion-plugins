---
name: "zion-vision:verify"
description: "Extends core 4-level verification with 5th Visual level"
user-invocable: true
allowed-tools: Read Write Bash Glob Grep
effort: medium
---

# /zion-vision:verify — Verify with Visual Fidelity

This skill extends `/zion:verify` with a 5th verification level: Visual. All core verification behavior is preserved; the visual level is additive.

## Precondition

Same as `/zion:verify`: at least one task in `.sdd/tasks.json` must have status `"done"`. If no tasks are done:
```
BLOCKED: No completed tasks to verify. Run /zion-vision:build first.
```

## Flow

### Step 1: Collect Criteria

Same as `/zion:verify` Step 1.

### Step 2: Auto-Detect Test Runner

Same as `/zion:verify` Step 2.

### Step 3: Run Test Suite

Same as `/zion:verify` Step 3.

### Step 4: 5-Level Verification

Run Levels 1-4 exactly as defined in `/zion:verify`:

#### Level 1: Exists
Does the file/function/route exist?

#### Level 2: Substantive
Is it real implementation, not a stub?

#### Level 3: Wired
Is it connected to the rest of the system?

#### Level 4: Functional
Does it actually work?

#### Level 5: Visual

This level applies only to UI criteria (criteria associated with files touching HTML/CSS/JSX/TSX/Vue/Svelte, or criteria mentioning visual/layout properties).

**Read `.sdd/vision-spec.json`.**

If vision-spec.json does not exist: skip Level 5 for all criteria. Print:
```
VISION: vision-spec.json not found — Level 5 skipped. Run /zion-vision:spec to enable.
```

If vision-spec.json exists, for each comparison entry:

1. Check that `result` is not `null`
   - If `null`: criterion fails Level 5 with evidence "No comparison result yet — run /zion-vision:compare"
2. Check that `result.computed_values` is a non-empty object
   - If missing or empty: criterion fails Level 5 with evidence "computed_values missing from result"
3. Check that `computed_values` contains numeric measurements (values with px, rem, %, em, or numeric units)
   - If none found: criterion fails Level 5 with evidence "No numeric measurements in computed_values"
4. Check fidelity: `result.fidelity >= 95`
   - If fidelity < 95: criterion fails Level 5 with evidence "Fidelity <X>% — below 95% threshold (<N> remaining diffs)"
   - If fidelity >= 95: criterion passes Level 5 with evidence "Fidelity <X>% — <comparison-name>"

A criterion passes Level 5 only if ALL of the above checks pass and fidelity >= 95%.

### Step 5: Write Results

Write `.sdd/verify-state.json` with the same schema as `/zion:verify`, but each criterion's `levels` object includes a `visual` key:

```json
{
  "levels": {
    "exists":       { "pass": true,  "evidence": "..." },
    "substantive":  { "pass": true,  "evidence": "..." },
    "wired":        { "pass": true,  "evidence": "..." },
    "functional":   { "pass": true,  "evidence": "..." },
    "visual":       { "pass": true,  "evidence": "Fidelity 97.5% — button-comparison" }
  },
  "status": "pass"
}
```

For non-UI criteria, `visual` is set to `{ "pass": true, "evidence": "N/A — not a UI criterion" }`.

A criterion passes only when ALL applicable levels pass (Levels 1-4 always apply; Level 5 applies to UI criteria when vision-spec.json exists).

### Step 6: Print Summary

```
VERIFICATION: <feature>
──────────────────────────────────────────────────────────────────
<total> criteria | <pass> pass | <fail> fail (<rate>%)

PASS  GET /health returns 200           █████ exists ✓ substantive ✓ wired ✓ functional ✓ visual N/A
PASS  Button renders correctly          █████ exists ✓ substantive ✓ wired ✓ functional ✓ visual ✓ (97.5%)
FAIL  Token rejects expired             ████▒ exists ✓ substantive ✓ wired ✓ functional ✗ visual —
FAIL  Card matches reference            ████▒ exists ✓ substantive ✓ wired ✓ functional ✓ visual ✗ (88%)

FAILURES:
  spec:3 token-validation — test_expired_token timeout (5s)
  spec:6 card-layout — Fidelity 88% — below 95% threshold (4 remaining diffs)
```

The summary bar legend:

| Bar | Meaning |
|-----|---------|
| `█████` | All 5 levels pass |
| `████▒` | Levels 1-4 pass, Level 5 fail or N/A |
| `███▒▒` | Levels 1-3 pass, Levels 4-5 fail |
| `██▒▒▒` | Levels 1-2 pass |
| `█▒▒▒▒` | Only Level 1 passes |
| `▒▒▒▒▒` | All levels fail |

## Do NOT

- Do not fix code — only verify and report
- Do not modify the spec or tasks
- Do not claim "close enough" — either the check passes or it doesn't
- Do not skip levels — check all 5 for every UI criterion (Levels 1-4 for non-UI)
- Do not block reporting if vision-spec.json is absent — skip Level 5 gracefully
