# Zion

Spec-Driven Development plugins for Claude Code. From idea to verified code with zero waste.

```
"Build me an auth middleware with JWT"
    → spec → plan → build → verify → done
```

## Install

```bash
/plugin marketplace add nicolaregattieri/zion-plugins
/plugin install zion-core@zion
/plugin install zion-vision@zion    # optional — for frontend/UI projects
```

## Requirements

- [Claude Code](https://claude.ai/code) (CLI, desktop app, or IDE extension)
- Git
- `jq` (used by hooks and bin scripts)
- **For zion-vision:** Node.js + Playwright (`npx playwright install chromium`)
- **For Figma references:** Figma personal access token (see [Figma Token Setup](#figma-token-setup))

## Quick Start

```
/zion:spec "Add rate limiting — max 100 req/min per IP"
/zion:plan
/zion:build
/zion:verify
```

Four commands, one feature, fully verified.

## Plugins

### zion-core — SDD Engine

The core workflow. Works with any language, any framework.

| Command | Purpose |
|---------|---------|
| `/zion:spec` | Generate TECH_SPEC.md from requirements (description, URL, or file path) |
| `/zion:plan` | Break spec into wave-based tasks with dependency graph |
| `/zion:build` | Execute tasks via fresh-agent loop — one task, one agent, one commit |
| `/zion:verify` | 4-level verification: exists → substantive → wired → functional |
| `/zion:fix` | Diagnose + fix verification failures or blocked tasks |
| `/zion:status` | Progress dashboard — works at any point, even with partial state |

### zion-vision — Visual QA

Extends core with measured visual verification. For frontend/UI projects.

| Command | Purpose |
|---------|---------|
| `/zion-vision:spec` | Core spec + visual reference capture + `vision-spec.json` |
| `/zion-vision:plan` | Core plan + visual acceptance criteria on UI tasks |
| `/zion-vision:build` | Core build + automatic visual comparison after each UI task |
| `/zion-vision:verify` | 5-level verification (core 4 + Visual fidelity check) |
| `/zion-vision:compare` | On-demand visual diff — computed styles, not screenshots |
| `/zion-vision:ref` | Capture reference from live URL, Figma, or screenshot |
| `/zion-vision:status` | Core dashboard + vision QA section |

Visual references can come from:
- **Live URL** — captures computed styles via Playwright + `getComputedStyle()`
- **Figma node** — extracts design tokens via Figma API
- **Screenshot file** — local image for Claude vision analysis

## Env & Token Security

Zion enforces a strict rule: **secrets never enter the agent context**.

- Tokens are stored in `.claude/settings.local.json` (per-project, gitignored)
- Two PreToolUse hooks block accidental reads:
  - `safe-bash.sh` — blocks `cat .env`, `source .env`, `grep .env`, etc.
  - `safe-read.sh` — blocks `Read(.env*)` and `Read(settings.local.json)`
- Agents access credentials only via `$VARIABLE_NAME` in Bash commands
- The value stays in the shell process and never enters the conversation

### Figma Token Setup

Only needed for `/zion-vision:ref` and `/zion-vision:spec` with Figma URLs.

```bash
# Run in your terminal (NOT in the Claude chat):
zion-figma-setup
```

This stores the token in `.claude/settings.local.json` as a plugin option. Claude Code injects it as `$CLAUDE_PLUGIN_OPTION_figma_token` at runtime.

To get a token: [figma.com/settings](https://www.figma.com/settings) → Personal access tokens → Generate new token.

## What Makes This Different

- **Quality gates BLOCK** — hooks exit non-zero. The agent cannot finish without meeting criteria.
- **Fresh agent per task** — each task gets a new agent with clean context. No context rot.
- **Measured verification** — 4-level depth with evidence, not "looks good".
- **Auto fix loop** — verify → diagnose → fix → re-verify. 3-cycle circuit breaker.
- **Visual QA with computed values** — `getComputedStyle()`, not "looks similar". 95% fidelity threshold.
- **Session survival** — close Claude, reopen, run `/zion:build` — resumes from where it stopped.

## MCP Servers

The `.mcp.json` at the root declares MCP servers used by the plugins:

- **Playwright** — browser automation for `zion-capture-styles` (visual reference capture)

When you clone this repo and open it with Claude Code, MCPs are available for approval automatically.

## Author

Nicola Regattieri — [zioncode.dev](https://zioncode.dev)
