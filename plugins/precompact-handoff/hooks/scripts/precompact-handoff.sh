#!/bin/bash
# PreCompact hook: summarize transcript into structured handoff doc before compaction.
set -euo pipefail

# Recursion guard: the child `claude -p` call below must not re-trigger this hook.
if [ -n "${PRECOMPACT_HANDOFF_CHILD:-}" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
HANDOFF_DIR="$PROJECT_DIR/.claude/handoff"
mkdir -p "$HANDOFF_DIR/logs"

INPUT="$(cat)"
echo "$INPUT" > "$HANDOFF_DIR/logs/last-precompact-input.json"

TRANSCRIPT_PATH="$(echo "$INPUT" | jq -r '.transcript_path // empty')"
TRIGGER="$(echo "$INPUT" | jq -r '.trigger // empty')"

if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

COMPACTION_MD="$PROJECT_DIR/compaction.md"
if [ -f "$COMPACTION_MD" ]; then
  PROMPT="$(cat "$COMPACTION_MD")"
else
  PROMPT='You are generating a structured handoff doc for a Claude Code session that is about to be compacted. Read the transcript (JSONL, one message per line) piped on stdin. Produce ONLY markdown with these exact sections:

# Handoff

## Key Decisions
(decisions made and why)

## Open Threads
(unresolved questions, pending work)

## File State
(files created/modified/read, with paths, and their current status)

## Next Steps
(concrete next actions, in order)

Be concise and specific. No generic summary filler.'
fi

HANDOFF_TMP="$HANDOFF_DIR/latest.md.tmp"

PRECOMPACT_HANDOFF_CHILD=1 claude -p "$PROMPT" \
  --model claude-sonnet-5 \
  < "$TRANSCRIPT_PATH" > "$HANDOFF_TMP" 2> "$HANDOFF_DIR/logs/last-precompact-stderr.log" || true

if [ -s "$HANDOFF_TMP" ]; then
  mv "$HANDOFF_TMP" "$HANDOFF_DIR/latest.md"
  {
    echo "---"
    date -u +"generated: %Y-%m-%dT%H:%M:%SZ"
    echo "trigger: $TRIGGER"
  } >> "$HANDOFF_DIR/latest.md"
else
  rm -f "$HANDOFF_TMP"
fi

exit 0
