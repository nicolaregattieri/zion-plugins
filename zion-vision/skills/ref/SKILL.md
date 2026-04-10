---
name: "zion-vision:ref"
description: "Captures visual reference from live URL, Figma node, or screenshot file"
user-invocable: true
allowed-tools: Read Write Bash Glob Grep
argument-hint: "<url|figma-url|screenshot-path> <name>"
effort: high
---

# /zion-vision:ref — Capture Visual Reference

You capture a visual reference and extract computed design values for later comparison. The reference is stored in `.sdd/refs/<name>/` and is the source of truth for the `zion-vision:compare` skill.

## Input

The user provides two arguments:

```
$ARGUMENTS
```

- **Argument 1**: The source — one of:
  - Live URL (`http://` or `https://`) — Live URL capture
  - Figma URL (`figma.com` domain) — Figma API extraction
  - File path (local screenshot) — Screenshot file import
- **Argument 2**: A short name (slug) for this reference, e.g. `hero-button`

Parse `$ARGUMENTS` to extract `SOURCE` and `NAME`.

## Step 1: Detect Input Type

Inspect the source argument:

| Condition | Type |
|---|---|
| Starts with `http://` or `https://` and does NOT contain `figma.com` | Live URL |
| Contains `figma.com` | Figma URL |
| Local file path (no `http`, not a Figma URL) | Screenshot file |

## Step 2: Prepare Output Directory

```bash
mkdir -p .sdd/refs/<name>
```

All outputs go to `.sdd/refs/<name>/`.

---

## Flow A: Live URL Capture

**Triggered by:** Live URL (http/https, non-Figma)

### A0 — Prepare Selectors File

`zion-capture-styles` needs a JSON file listing which CSS selectors to measure. Create a temp file:

```bash
echo '["h1", ".hero", ".btn-primary", ".card"]' > /tmp/zion-selectors.json
```

Where do selectors come from:
- If `.sdd/vision-spec.json` exists: use its `focus_areas[].selector` values
- If the user specified selectors: use those
- Otherwise: inspect the page and pick the main structural elements (headings, buttons, cards, nav)

### A1 — Desktop Capture (1440px viewport)

Call `bin/zion-capture-styles` with the desktop viewport:

```bash
zion-capture-styles <url> /tmp/zion-selectors.json desktop .sdd/refs/<name>/desktop
```

This produces:
- `.sdd/refs/<name>/desktop/screenshot.png` — full-page screenshot
- Stdout JSON in `design-values.json` format (redirect to file)

Rename/copy the screenshot:

```
.sdd/refs/<name>/ref-desktop.png
```

Save the captured style JSON:

```
.sdd/refs/<name>/desktop/design-values.json
```

### A2 — Mobile Capture (375px viewport)

Call `bin/zion-capture-styles` a second time with the mobile viewport:

```bash
zion-capture-styles <url> /tmp/zion-selectors.json mobile .sdd/refs/<name>/mobile
```

Outputs:
- `.sdd/refs/<name>/mobile/screenshot.png` → copy as `.sdd/refs/<name>/ref-mobile.png`
- `.sdd/refs/<name>/mobile/design-values.json`

### A3 — Write source.json

```json
{
  "type": "live-url",
  "origin": "<url>",
  "name": "<name>",
  "captured_at": "<ISO-8601>",
  "viewports": ["desktop", "mobile"],
  "files": {
    "ref-desktop.png": ".sdd/refs/<name>/ref-desktop.png",
    "ref-mobile.png": ".sdd/refs/<name>/ref-mobile.png",
    "desktop-values": ".sdd/refs/<name>/desktop/design-values.json",
    "mobile-values": ".sdd/refs/<name>/mobile/design-values.json"
  }
}
```

---

## Flow B: Figma URL

**Triggered by:** URL containing `figma.com`

### B1 — Extract Node Data and Rendered PNG

Call `bin/zion-figma-extract`:

```bash
zion-figma-extract <figma-url> .sdd/refs/<name>
```

This produces:
- `.sdd/refs/<name>/node.json` — raw Figma node data
- `.sdd/refs/<name>/node.png` — rendered PNG from Figma's image API
- `.sdd/refs/<name>/design-values.json` — extracted design values

### B2 — Write source.json

```json
{
  "type": "figma-url",
  "origin": "<figma-url>",
  "name": "<name>",
  "captured_at": "<ISO-8601>",
  "files": {
    "node-data": ".sdd/refs/<name>/node.json",
    "rendered-png": ".sdd/refs/<name>/node.png",
    "design-values": ".sdd/refs/<name>/design-values.json"
  }
}
```

---

## Flow C: Screenshot File Import

**Triggered by:** Local file path (no http prefix, not a Figma URL)

### C1 — Copy the Screenshot

Copy the provided file into the reference directory as `ref-screenshot.png`:

```bash
cp <screenshot-path> .sdd/refs/<name>/ref-screenshot.png
```

### C2 — Write source.json

Because this is a static screenshot (no live DOM), there are **no computed style values**. Claude vision analysis is the only available method.

```json
{
  "type": "screenshot-file",
  "origin": "<screenshot-path>",
  "name": "<name>",
  "captured_at": "<ISO-8601>",
  "note": "no computed values, Claude vision analysis only",
  "files": {
    "ref-screenshot.png": ".sdd/refs/<name>/ref-screenshot.png"
  }
}
```

---

## Image Optimization

All screenshots must meet these constraints for Claude token efficiency:

- **Max long edge**: 1568px (enforced by `zion-capture-styles` via sharp)
- **Format**: PNG
- **Token budget**: approximately 1600 tokens per image

`zion-capture-styles` automatically resizes screenshots when sharp is available. For manually copied screenshots (Flow C), warn if the image exceeds 1568px on its longest edge.

---

## Output Files Summary

| File | Live URL | Figma URL | Screenshot |
|---|---|---|---|
| `ref-desktop.png` | Yes | No | No |
| `ref-mobile.png` | Yes | No | No |
| `desktop/design-values.json` | Yes | No | No |
| `mobile/design-values.json` | Yes | No | No |
| `node.json` | No | Yes | No |
| `node.png` | No | Yes | No |
| `design-values.json` | No | Yes | No |
| `ref-screenshot.png` | No | No | Yes |
| `source.json` | Yes | Yes | Yes |

`source.json` is always created, regardless of input type.

---

## Summary

After completing, print:

```
REF CAPTURED: <name>
  Type   : <live-url | figma-url | screenshot-file>
  Origin : <source>
  Files  : .sdd/refs/<name>/
  Run /zion-vision:compare to measure build fidelity.
```
