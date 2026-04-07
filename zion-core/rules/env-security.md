# Env Security

## Rules

- NEVER read `.env`, `.env.*`, or any dotenv file directly (no Read, no cat, no grep on the file)
- NEVER read `.claude/settings.local.json` — it may contain tokens via pluginOptions
- NEVER ask the user to paste tokens, passwords, or secrets in the chat
- Access credentials ONLY via `$VARIABLE_NAME` in Bash commands (e.g., `$DATABASE_URL`)
- If a command needs a secret, pass it through environment variables — never interpolate into strings

## Why

The agent context is sent to the API. Any secret that enters the conversation — via Read output, Bash stdout, or user paste — is transmitted externally. Shell environment variables stay in the Bash process and never enter the conversation context.

## Enforcement

Two PreToolUse hooks enforce these rules automatically:

- **safe-bash.sh** — blocks `cat .env`, `source .env`, `grep .env`, and similar Bash commands
- **safe-read.sh** — blocks `Read(.env*)` and `Read(settings.local.json)` via the Read tool

If you need a secret's value, reference it as `$VAR_NAME` in a Bash command. The value stays in the shell process.
