---
name: "zion-vision:status"
description: "Extends core dashboard with vision QA section"
user-invocable: true
allowed-tools: Read Glob
effort: low
---

# /zion-vision:status — Progress Dashboard with Vision QA

This skill extends `/zion:status` with a VISION QA section appended after the core dashboard sections. All core status behavior is preserved.

## Flow

### Steps 1-3: Core Dashboard

Run all steps from `/zion:status` exactly as defined:

1. Read state files (spec-state.json, TECH_SPEC.md, tasks.json, build-log.json, verify-state.json, .active, learnings.md)
2. Compute metrics
3. Print the core dashboard

### Step 4: Vision QA Section

After printing the core dashboard, check for `.sdd/vision-spec.json`.

**If vision-spec.json does not exist:** skip this section silently. Do not print any vision-related output.

**If vision-spec.json exists:** read it and print the VISION QA section:

```
VISION QA
──────────────────────────────────────────────────────────────────
Comparison              Status   Fidelity   Diffs Left   Rounds
──────────────────────────────────────────────────────────────────
button-primary          pass     97.5%      0            2/3
card-layout             fail     88.0%      4            3/3
hero-section            pending  —          —            —
nav-bar                 pass     99.1%      0            1/3
──────────────────────────────────────────────────────────────────
VISION: 2 pass | 1 fail | 1 pending
```

Column definitions:

| Column | Source |
|--------|--------|
| Comparison | `comparisons[i].name` |
| Status | `comparisons[i].result.status` — `"pass"`, `"fail"`, or `"pending"` (if `result` is `null`) |
| Fidelity | `comparisons[i].result.fidelity` formatted as percentage, or `—` if pending |
| Diffs Left | `comparisons[i].result.remaining_diffs` array length, or `—` if pending |
| Rounds | Number of rounds used (derived from fix history if available), or `—` if pending |

**Status determination:**
- `result` is `null` → `pending`
- `result.status` is `"pass"` → `pass`
- `result.status` is `"fail"` → `fail`

**Fidelity display:**
- Format to one decimal place: `97.5%`
- If pending: `—`

**Summary line:**
Count pass, fail, and pending comparisons. Print:
```
VISION: <N> pass | <N> fail | <N> pending
```

If all comparisons pass, add:
```
VISION: All comparisons passing at >= 95% fidelity
```

If any comparisons fail:
```
VISION: <N> comparison(s) need attention — run /zion-vision:compare to fix
```

## Do NOT

- Do not modify any state files — status is read-only
- Do not run comparisons or tests — just read existing state from vision-spec.json
- Do not show the VISION QA section if vision-spec.json is absent
- Do not report errors if vision-spec.json is absent — skip silently
