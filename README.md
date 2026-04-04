# Zion Plugins

Spec-Driven Development plugins for Claude Code.

## Install

```bash
/plugin marketplace add nicolaregattieri/zion-plugins
/plugin install zion-core@zion
/plugin install zion-vision@zion    # optional, for frontend/UI projects
```

## Plugins

### zion-core

SDD engine — from idea to verified code with zero waste.

| Command | Purpose |
|---------|---------|
| `/zion:spec` | Generate TECH_SPEC.md from requirements |
| `/zion:plan` | Break spec into wave-based tasks |
| `/zion:build` | Execute tasks via fresh-agent loop + auto-verify + auto-fix |
| `/zion:verify` | 4-level verification (exists → substantive → wired → functional) |
| `/zion:fix` | Diagnose + fix failures or blocked tasks |
| `/zion:status` | Progress dashboard |

### zion-vision

Visual QA with computed-style verification. Extends zion-core for frontend/UI projects.

| Command | Purpose |
|---------|---------|
| `/zion-vision:ref` | Capture reference (URL, Figma, screenshot) + getComputedStyle() |
| `/zion-vision:compare` | Measured visual diff — numbers, not vibes |
| `/zion-vision:spec` | Core spec + vision-spec.json |
| `/zion-vision:build` | Core build + visual QA per task |
| `/zion-vision:verify` | 5-level verification (+ Visual) |

## What makes this different

- **Quality gates BLOCK** — hooks exit 2, not suggestions
- **Fresh agent per task** — no context rot
- **Measured verification** — 4-level depth with evidence
- **Auto fix loop** — verify → diagnose → fix → re-verify
- **Visual QA with computed values** — getComputedStyle(), not "looks similar"

## Author

Nicola Regattieri — [zioncode.dev](https://zioncode.dev)
