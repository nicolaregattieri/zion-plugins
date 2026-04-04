#!/bin/bash
# safe-bash.sh — PreToolUse hook for Bash commands
# Auto-approves safe commands used by the SDD pipeline.
# Denies dangerous commands.
# Pattern from ai-shopify-plan, generalized for any project.

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')

# Only handle Bash tool
if [ "$TOOL" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Extract the base command (first word, ignoring env vars and paths)
BASE_CMD=$(echo "$COMMAND" | sed 's/^[A-Z_]*=[^ ]* //' | awk '{print $1}' | sed 's|.*/||')

# Deny list — block by BASE command, not substring match
case "$BASE_CMD" in
  sudo)  DENY="sudo not allowed" ;;
  dd)    DENY="dd not allowed" ;;
  mkfs)  DENY="filesystem format not allowed" ;;
  *)     DENY="" ;;
esac

# Pattern-based denies (only if base command didn't match)
if [ -z "$DENY" ]; then
  case "$COMMAND" in
    *"rm -rf /"*)      DENY="dangerous rm" ;;
    *"rm -rf ~"*)      DENY="dangerous rm" ;;
    *"chmod -R 777"*)  DENY="dangerous chmod" ;;
    *"> /dev/s"*)      DENY="device write not allowed" ;;
    *"> /dev/d"*)      DENY="device write not allowed" ;;
    *)                 DENY="" ;;
  esac
fi

if [ -n "$DENY" ]; then
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked: $DENY"}}
EOF
  exit 0
fi

# Allow list — auto-approve these base commands
case "$BASE_CMD" in
  # File operations (read-only or project-scoped)
  ls|find|cat|head|tail|wc|sort|uniq|diff|file|stat|tree)
    ALLOW=true ;;
  # Search
  grep|rg|awk|sed|tr|cut)
    ALLOW=true ;;
  # Directory operations
  mkdir|cp|mv|touch)
    ALLOW=true ;;
  # JSON/text processing
  jq|yq|python3|python|node)
    ALLOW=true ;;
  # Git (read + safe write)
  git)
    ALLOW=true ;;
  # Package managers (read + install)
  npm|npx|yarn|pnpm|pip|cargo|go|bundle|make)
    ALLOW=true ;;
  # Testing
  jest|vitest|pytest|mocha)
    ALLOW=true ;;
  # Build tools
  tsc|esbuild|webpack|vite|next|nuxt)
    ALLOW=true ;;
  # Shell utilities
  echo|printf|date|basename|dirname|realpath|which|type|command|env|export|cd|test|true|false|rm)
    ALLOW=true ;;
  # Hashing
  shasum|sha256sum|md5|md5sum)
    ALLOW=true ;;
  # Network (read-only)
  curl|wget)
    ALLOW=true ;;
  # Zion bin helpers
  zion-*)
    ALLOW=true ;;
  # chmod for our own scripts
  chmod)
    ALLOW=true ;;
  *)
    ALLOW=false ;;
esac

if [ "$ALLOW" = true ]; then
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}
EOF
fi

exit 0
