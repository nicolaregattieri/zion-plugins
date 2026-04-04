---
name: "zion:verify"
description: "After build completes, or on-demand to check implementation against spec"
user-invocable: true
allowed-tools: Read Write Bash Glob Grep
---

# /zion:verify — Verify Against Spec

You verify that the implementation meets the specification's acceptance criteria using 4 levels of verification depth. You produce evidence, not opinions.

## Precondition

At least one task in `.sdd/tasks.json` must have status `"done"`. If no tasks are done:
```
BLOCKED: No completed tasks to verify. Run /zion:build first.
```

## Flow

### Step 1: Collect Criteria

Read criteria from two sources:
1. `.sdd/TECH_SPEC.md` — spec-level acceptance criteria
2. `.sdd/tasks.json` — per-task criteria

Deduplicate: task criteria that directly implement spec criteria map to the same check.

Build a unified list with source tracking:
```
spec:1 → "GET /health returns 200" → `curl ...`
spec:2 �� "Auth rejects expired tokens" → `npm test -- auth.test.ts`
task:3 → "Token validator exports validateToken" → (derived)
```

### Step 2: Auto-Detect Test Runner

Based on project root files:
- `package.json` with "test" script → `npm test` (or yarn/pnpm based on lockfile)
- `go.mod` → `go test ./...`
- `pyproject.toml` or `pytest.ini` → `pytest`
- `Cargo.toml` → `cargo test`
- `.sdd/config.json` with "test_command" → use that
- None detected → skip functional checks, warn user

### Step 3: Run Test Suite

Execute the detected test command. Capture output and exit code.

### Step 4: 4-Level Verification

For each criterion, check all 4 levels in order:

#### Level 1: Exists
Does the file/function/route exist?
- Use Glob to check file paths
- Use Grep to check function/export names
- Evidence: "src/auth/middleware.ts exists" or "MISSING: src/auth/middleware.ts"

#### Level 2: Substantive
Is it real implementation, not a stub?
- Grep for TODO, FIXME, placeholder, "not implemented", `throw new Error('TODO')`
- Check function body length > trivial (more than just a return statement)
- Evidence: "validateToken() has 24 lines with expiry check logic" or "STUB: function body is empty/placeholder"

#### Level 3: Wired
Is it connected to the rest of the system?
- Grep for imports/requires of the file across the codebase
- Check route registration (if applicable)
- Verify exports are consumed somewhere
- Evidence: "imported in src/routes/index.ts:14, registered at :28" or "NOT WIRED: no imports found"

#### Level 4: Functional
Does it actually work?
- Run the specific verification command from the criterion
- Capture exit code and output
- Evidence: "test auth.test.ts PASS (6/6 assertions)" or "FAIL: test_expired_token timeout 5s"

### Step 5: Write Results

Write `.sdd/verify-state.json`:

```json
{
  "version": 1,
  "spec_hash": "<from spec-state.json>",
  "verified_at": "<ISO-8601>",
  "test_runner": "<detected>",
  "test_result": "pass|fail|skip",
  "criteria": [
    {
      "source": "spec:1",
      "criterion": "GET /health returns 200",
      "command": "curl -s -o /dev/null -w '%{http_code}' localhost:8080/health",
      "levels": {
        "exists": { "pass": true, "evidence": "src/routes/health.ts exists" },
        "substantive": { "pass": true, "evidence": "handler has 12 lines, returns JSON" },
        "wired": { "pass": true, "evidence": "imported in src/routes/index.ts:14" },
        "functional": { "pass": true, "evidence": "curl returns 200 OK" }
      },
      "status": "pass"
    }
  ],
  "summary": {
    "total": 0,
    "pass": 0,
    "fail": 0,
    "pass_rate": "0%"
  }
}
```

A criterion passes only when ALL 4 levels pass. If any level fails, the criterion fails at that level (higher levels are not checked).

### Step 6: Print Summary

```
VERIFICATION: <feature>
────────────────────────────────────────────────────────
<total> criteria | <pass> pass | <fail> fail (<rate>%)

PASS  GET /health returns 200                    ████ exists ✓ substantive ✓ wired ✓ functional ✓
PASS  Auth blocks unauthenticated                ████ exists ✓ substantive ✓ wired ✓ functional ✓
FAIL  Token rejects expired                      ███░ exists ✓ substantive ✓ wired ✓ functional ✗
FAIL  Rate limiter caps 100 req/min              ██░░ exists ✓ substantive ✓ wired ✗ functional ✗

FAILURES:
  spec:3 token-validation — test_expired_token timeout (5s)
  spec:7 rate-limiter — rate_limiter.ts not imported anywhere (wired check failed)

Run /zion:fix to auto-diagnose and repair failures.
```

## Do NOT

- Do not fix code — only verify and report
- Do not modify the spec or tasks
- Do not claim "close enough" — either the check passes or it doesn't
- Do not skip levels — check all 4 for every criterion
