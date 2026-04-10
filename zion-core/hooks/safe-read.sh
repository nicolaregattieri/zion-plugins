#!/bin/bash
# safe-read.sh — PreToolUse hook for Read tool
# Blocks reading of .env files and other credential-bearing files.
# Secrets in Read output enter the agent context → transmitted to API.

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')

# Only handle Read tool
if [ "$TOOL" != "Read" ]; then
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
BASENAME=$(basename "$FILE_PATH")

# Block .env files (any dotenv variant)
case "$BASENAME" in
  .env|.env.*)
    cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked: .env file read — secrets would enter agent context. Use \$VAR in Bash commands instead."}}
EOF
    exit 0
    ;;
esac

# Block settings.local.json (may contain plugin option tokens)
case "$BASENAME" in
  settings.local.json)
    cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked: settings.local.json may contain tokens via pluginOptions."}}
EOF
    exit 0
    ;;
esac

exit 0
