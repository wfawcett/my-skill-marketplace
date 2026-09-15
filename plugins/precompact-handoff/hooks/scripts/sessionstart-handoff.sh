#!/bin/bash
# SessionStart hook (source=compact): reinject the custom handoff doc as context.
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
HANDOFF_FILE="$PROJECT_DIR/.claude/handoff/latest.md"

if [ ! -f "$HANDOFF_FILE" ]; then
  exit 0
fi

CONTENT="$(cat "$HANDOFF_FILE")"
jq -n --arg ctx "$CONTENT" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
exit 0
