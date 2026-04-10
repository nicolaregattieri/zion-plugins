# Zion Vision

Visual QA with computed-style verification. Extends [zion-core](../zion-core/) for frontend/UI projects.

```
"Match this Figma design exactly"
    → ref capture → spec → plan → build → visual compare → verified (95%+ fidelity)
```

## Requirements

Everything from zion-core, plus:

- **Node.js** (for Playwright)
- **Playwright** — `npx playwright install chromium`
- **Figma token** (optional) — only if using Figma URLs as references

## Figma Token Setup

Only needed when you pass a Figma URL to `/zion-vision:ref` or `/zion-vision:spec`.

```bash
# Run in your terminal (NOT in the Claude chat):
zion-figma-setup
```

What this does:
1. Asks for your Figma personal access token (input is hidden)
2. Saves it to `.claude/settings.local.json` as a plugin option:
   ```json
   {
     "pluginOptions": {
       "zion-vision": {
         "figma_token": "figd_xxxxx"
       }
     }
   }
   ```
3. Claude Code injects it as `$CLAUDE_PLUGIN_OPTION_figma_token` at runtime

**Why settings.local.json:**
- Native Claude Code mechanism — no custom loaders
- Per-project (each repo has its own)
- Already gitignored — never committed
- `zion-figma-extract` reads the env var directly — zero config

**To get a token:** [figma.com/settings](https://www.figma.com/settings) → Personal access tokens → Generate new token.

**Verify setup:**
```bash
zion-figma-setup --check
```

## Commands

### `/zion-vision:ref` — Capture Reference

Capture a visual reference to compare against later.

```
/zion-vision:ref https://example.com/page hero-section     # from live URL
/zion-vision:ref https://figma.com/design/xxx?node-id=1:2 hero-section  # from Figma
/zion-vision:ref screenshot.png hero-section                # from local file
```

| Source | What it captures |
|--------|-----------------|
| **Live URL** | Screenshots (desktop + mobile) + computed CSS values via `getComputedStyle()` |
| **Figma URL** | Node screenshot + design tokens (font-size, color, padding, etc.) via Figma API |
| **Screenshot** | Image only — Claude vision analysis, no computed values |

Live URL captures at two viewports: desktop (1440px) and mobile (375px).

Output goes to `.sdd/refs/<name>/`.

### `/zion-vision:spec` — Specify with Visual Contract

```
/zion-vision:spec "Rebuild the hero section to match this Figma"
/zion-vision:spec https://figma.com/design/xxx?node-id=1:2
/zion-vision:spec https://staging.example.com/page
```

Does everything `/zion:spec` does, plus:
1. Captures visual reference (Figma, URL, or file)
2. Generates `.sdd/vision-spec.json` with focus areas, comparisons, and breakpoints
3. Each comparison defines: reference path, build URL, breakpoints (min 375px + 1440px), focus area selectors

### `/zion-vision:plan` — Plan with Visual Criteria

```
/zion-vision:plan
```

Does everything `/zion:plan` does, plus:
- Detects UI tasks (files with `.html`, `.css`, `.scss`, `.jsx`, `.tsx`, `.vue`, `.svelte`)
- Injects visual acceptance criteria: selectors, breakpoints, reference file, comparison command

### `/zion-vision:build` — Build with Visual Comparison

```
/zion-vision:build              # full auto
/zion-vision:build --safe       # approve each task
/zion-vision:build --dry        # no commits
/zion-vision:build --pr         # auto + PR
```

Does everything `/zion:build` does, plus:
- After each UI task completes: runs visual comparison automatically
- Captures build state via `zion-capture-styles`, compares with `zion-compare-values`
- Fidelity < 95% = warning, logged in `vision-spec.json` for review

### `/zion-vision:compare` — Measure Fidelity

On-demand visual comparison against the reference.

```
/zion-vision:compare                    # all pending comparisons
/zion-vision:compare hero-section       # specific comparison
```

What happens:
1. Captures computed styles from build URL via Playwright
2. Compares against reference using `zion-compare-values` (95% threshold)
3. If fidelity < 95%: fix CSS, re-measure (max 3 rounds)
4. Writes result to `vision-spec.json` with: status, computed values, diffs, fidelity

**Measured, not guessed.** Every comparison produces numeric deltas (e.g., `font-size: expected 16px, actual 14px, delta 2px`).

### `/zion-vision:verify` — 5-Level Verification

```
/zion-vision:verify
```

Core 4 levels + Level 5: Visual.

| Level | What |
|-------|------|
| Exists | File/function present |
| Substantive | Real code, not stubs |
| Wired | Connected to the system |
| Functional | Passes verification command |
| **Visual** | Computed-style fidelity >= 95% |

Level 5 checks: `vision-spec.json` result is not null, `computed_values` are non-empty, fidelity meets threshold.

### `/zion-vision:status` — Dashboard

```
/zion-vision:status
```

Core dashboard + vision QA section showing: comparison name, status, fidelity %, diffs remaining, rounds used.

## Architecture

```
zion-vision/
├── .claude-plugin/plugin.json       # Plugin metadata
├── skills/                          # 7 commands (spec, plan, build, verify, compare, ref, status)
├── agents/
│   ├── spec-writer.md               # Opus — spec + vision-spec.json generation
│   └── task-executor.md             # Sonnet — code only, no visual QA responsibility
├── hooks/
│   ├── hooks.json                   # SessionStart, Stop
│   ├── vision-bootstrap.sh          # Inject visual QA context
│   └── vision-stop-gate.sh          # Block exit with unmeasured comparisons
├── rules/
│   ├── vision-qa.md                 # Eyeball+Ruler pattern, 8 anti-rationalization rules
│   └── figma-token.md               # Token handling via plugin options
├── bin/
│   ├── zion-figma-extract           # Figma API → design-values.json + screenshot
│   ├── zion-figma-setup             # Interactive Figma token setup
│   ├── zion-require-figma-token     # JIT gate — checks token before API calls
│   ├── zion-capture-styles          # Playwright → computed CSS + screenshot
│   └── zion-compare-values          # Compare two design-values → fidelity + diffs
└── templates/
    ├── vision-spec.template.json    # Comparisons, focus areas, breakpoints
    └── design-values.template.json  # Captured CSS property values
```

## Quality Gates

| Gate | When | What |
|------|------|------|
| Vision stop gate | Session stop | Blocks if any comparison has `result: null` (not measured) |
| Computed values required | During compare | Blocks if comparison has no numeric measurements |
| Fidelity threshold | During compare | 95% minimum — below = fail |
| 3-round limit | During compare | Max 3 measure→fix→re-measure cycles per comparison |
| Anti-rationalization | Agent rules | 8 documented failure modes from battle-testing (see `vision-qa.md`) |

## How Visual Comparison Works

```
Reference (Figma/URL)          Build (dev server)
        │                              │
        ▼                              ▼
  design-values.json             design-values.json
  (font-size, color,             (font-size, color,
   padding, gap...)               padding, gap...)
        │                              │
        └──────────┬───────────────────┘
                   ▼
          zion-compare-values
                   │
                   ▼
          { fidelity: 97.2%,
            diffs: [{ property: "color",
                      expected: "#1a1a1a",
                      actual: "#1b1b1b",
                      delta: 1 }],
            pass: true }
```

No "looks similar" — every property is measured via `getComputedStyle()` and compared numerically.
