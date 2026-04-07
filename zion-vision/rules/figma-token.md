# Figma Token

## How it works

The Figma API token is managed via Claude Code's **plugin options** mechanism:

1. User runs `zion-figma-setup` (interactive, in terminal — NOT in chat)
2. Token is saved to `.claude/settings.local.json` under `pluginOptions.zion-vision.figma_token`
3. Claude Code injects it as `CLAUDE_PLUGIN_OPTION_figma_token` env var at runtime
4. `zion-figma-extract` reads this env var (never the file directly)

## Rules

- **Before any Figma API call**, run `zion-require-figma-token` — it gates on missing token
- NEVER read `.claude/settings.local.json` directly — it contains the token in plaintext
- NEVER ask the user to paste a Figma token in the chat
- If token is missing, instruct the user to run `zion-figma-setup` in their terminal (not in chat)
- Access the token ONLY via `$CLAUDE_PLUGIN_OPTION_figma_token` in Bash commands

## Why

The token is a personal access credential. If it enters the conversation context (via Read, cat, or user paste), it is transmitted to the API. The plugin options mechanism keeps it in the shell process only.
