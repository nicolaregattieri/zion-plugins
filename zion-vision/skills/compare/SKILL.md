---
name: "zion-vision:compare"
description: "Measures build against reference using computed styles"
user-invocable: true
allowed-tools: Read Write Edit Bash Glob Grep
argument-hint: "[comparison-name]"
effort: high
---

# /zion-vision:compare — Measure Build Fidelity Against Reference

You measure how closely the current build matches the captured visual reference by taking screenshots of the build, extracting computed style values, and computing numeric diffs.

## Input

```
$ARGUMENTS
```

Optional `[comparison-name]` to run a single named comparison. If omitted, run all comparisons where `result` is `null`.

## Precondition Check

**Read `.sdd/vision-spec.json` first.**

If the file does not exist, stop immediately:

```
ERROR: .sdd/vision-spec.json not found.
Run /zion-vision:spec to create it, then /zion-vision:ref to capture references.
```

---

## Step 1: Read vision-spec.json

Load `.sdd/vision-spec.json`. Identify all comparisons where `result` is `null` (or matches the optional `[comparison-name]` argument).

Each comparison entry has:
- `name` — identifier
- `ref_path` — path to reference directory (e.g., `.sdd/refs/hero-button/`)
- `build_url` — the URL of the build to screenshot
- `breakpoints` — list of `{ viewport, width }` entries to test
- `focus_areas` — list of CSS selectors to measure
- `result` — `null` means not yet measured

### Detect Reference Type

Read `<ref_path>/source.json` to determine the reference type:
- `"type": "live-url"` → has `desktop/` and `mobile/` subdirs with `design-values.json`
- `"type": "figma-url"` → has `design-values.json` at root (no viewport subdirs)
- `"type": "screenshot-file"` → image only, no computed values (skip numeric comparison, use Claude vision only)

---

## Step 2: Measure Build

For each pending comparison, execute up to **3 rounds** of measure → diff → fix → re-measure.

### The Eyeball + Ruler Pattern

Claude vision identifies **what to look at**. `getComputedStyle()` measures **the actual values**.

- Never use subjective language ("looks good", "seems close") — only report numeric deltas
- Claude vision is used to identify focus areas, spot unexpected layout shifts, and verify structural correctness
- `zion-capture-styles` uses `window.getComputedStyle()` to extract exact px/rem/weight values

### Per Round

**Round 1 — Initial Measure**

Write the comparison's `focus_areas` to a temp JSON array file (e.g., `/tmp/selectors.json`).

Call `bin/zion-capture-styles` for each breakpoint in the comparison:

```bash
zion-capture-styles <build_url> <selectors-file> <viewport> .sdd/compare/<name>/<viewport>
```

Then compare against the reference. Adapt the ref path based on source type:

**Live URL refs** (have viewport subdirs):
```bash
zion-compare-values \
  <ref_path>/<viewport>/design-values.json \
  .sdd/compare/<name>/<viewport>/design-values.json \
  95
```

**Figma refs** (flat structure, single design-values.json):
```bash
zion-compare-values \
  <ref_path>/design-values.json \
  .sdd/compare/<name>/desktop/design-values.json \
  95
```

**Screenshot refs** (no computed values): skip `zion-compare-values`. Use Claude vision to compare images only. Mark result with `"computed_values": {}` and `"note": "screenshot-only comparison"`.

The output JSON contains:
- `diffs` — array of `{ property, selector, expected, actual, delta, unit }`
- `fidelity` — percentage of matching property pairs (0–100)
- `pass` — boolean, true if fidelity >= threshold (default 95)

**Round 2 and 3 — Fix and Re-measure**

If `pass` is false:
1. Read the `diffs` array — identify which properties and selectors are off
2. Fix the CSS/component code to address the diffs
3. Re-run `zion-capture-styles` and `zion-compare-values`
4. Increment round counter

**Hard stop at 3 rounds.** Do not attempt a 4th round. Write whatever result was achieved in round 3.

---

## Step 3: Multi-Image Comparison

When presenting reference vs build screenshots to Claude vision for analysis, always label images and place them BEFORE the explanatory text:

```
Reference: [image of .sdd/refs/<ref_path>/ref-desktop.png]
Build: [image of .sdd/compare/<name>/desktop/screenshot.png]

Analysis: The reference shows X, the build shows Y...
```

Use "Reference:" and "Build:" as the exact labels. Images must appear BEFORE any text description.

---

## Step 4: Write Result to vision-spec.json

After completing all rounds for a comparison, write the result back into `.sdd/vision-spec.json` under that comparison's `result` field:

```json
{
  "status": "pass",
  "computed_values": {
    ".btn": {
      "font-size": "16px",
      "font-weight": "600",
      "padding": "8px 16px"
    }
  },
  "diffs": [
    {
      "property": "font-size",
      "selector": ".btn",
      "expected": "16px",
      "actual": "14px",
      "delta": 2.0,
      "unit": "px"
    }
  ],
  "fidelity": 97.5,
  "fixes_applied": [
    "Increased .btn font-size from 14px to 16px in src/components/Button.css"
  ],
  "remaining_diffs": []
}
```

**All result fields are required:**

| Field | Type | Description |
|---|---|---|
| `status` | `"pass"` or `"fail"` | Whether fidelity met threshold |
| `computed_values` | object | Full getComputedStyle output for each selector |
| `diffs` | array | Each entry has `property`, `expected`, `actual`, `delta` |
| `fidelity` | number | Percentage of matching property pairs |
| `fixes_applied` | array | Human-readable list of code changes made |
| `remaining_diffs` | array | Diffs that could not be resolved in 3 rounds |

Use **Edit** (not Write) to update `vision-spec.json` so only the `result` field is modified, leaving other comparison entries intact.

---

## Step 5: Summary

After all pending comparisons are processed, print:

```
COMPARE COMPLETE
  Comparisons run : N
  Passed          : N (fidelity >= 95%)
  Failed          : N
  Rounds used     : up to 3 per comparison

Results written to .sdd/vision-spec.json
```

---

## Rules

- **Never** describe images with subjective language — use computed_values and deltas only
- **Never** run more than 3 rounds per comparison
- **Always** use `getComputedStyle()` values (via `zion-capture-styles`) as the source of truth for numeric properties
- **Always** use Claude vision to guide focus — identify regions, spot layout issues, direct selector choices
- **Always** write `result` back to `vision-spec.json` after each comparison, even if rounds are exhausted with `status: "fail"`
- Diffs array entries must include `property`, `expected`, `actual`, and `delta` — no entries without all four fields
