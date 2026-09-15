#!/bin/bash
# Lightweight test harness for precompact-handoff.sh (no existing shell-test
# framework found in this repo, so this is self-contained).
#
# Covers the bug where a failed child `claude -p` summarization call (nonzero
# exit and/or error text on stdout) overwrote a last-good latest.md handoff.
#
# Usage: ./test-precompact-handoff.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/precompact-handoff.sh"

FAIL=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAIL=1; }

setup_case() {
  # sets: TMPDIR_CASE, FAKE_BIN, HANDOFF_DIR
  TMPDIR_CASE="$(mktemp -d)"
  FAKE_BIN="$TMPDIR_CASE/fakebin"
  mkdir -p "$FAKE_BIN"
  HANDOFF_DIR="$TMPDIR_CASE/.claude/handoff"
  mkdir -p "$HANDOFF_DIR/logs"
  echo "GOOD PRIOR HANDOFF - DO NOT LOSE ME" > "$HANDOFF_DIR/latest.md"
  echo '{"role":"user","content":"hello"}' > "$TMPDIR_CASE/transcript.jsonl"
}

run_hook() {
  local input
  input="$(cat <<EOF
{"transcript_path": "$TMPDIR_CASE/transcript.jsonl", "trigger": "manual"}
EOF
)"
  echo "$input" | PATH="$FAKE_BIN:$PATH" CLAUDE_PROJECT_DIR="$TMPDIR_CASE" bash "$HOOK_SCRIPT"
}

### Case 1: child call FAILS (nonzero exit + error text on stdout) ###
echo "== Case 1: failing child call must not clobber latest.md =="
setup_case
GOOD_CONTENT="$(cat "$HANDOFF_DIR/latest.md")"

cat > "$FAKE_BIN/claude" <<'EOF'
#!/bin/bash
cat > /dev/null
echo "Prompt is too long · the request is ~1094895 tokens (limit 1000000) · unable to complete request"
exit 1
EOF
chmod +x "$FAKE_BIN/claude"

run_hook

AFTER_CONTENT="$(cat "$HANDOFF_DIR/latest.md" 2>/dev/null || echo "<<MISSING>>")"
if [ "$AFTER_CONTENT" = "$GOOD_CONTENT" ]; then
  pass "latest.md unchanged after failed child call"
else
  fail "latest.md was overwritten/lost after failed child call"
fi

if grep -qi "fail" "$HANDOFF_DIR/logs/last-precompact-stderr.log" 2>/dev/null; then
  pass "failure logged in last-precompact-stderr.log"
else
  fail "no failure recorded in last-precompact-stderr.log"
fi

rm -rf "$TMPDIR_CASE"

### Case 2: child call SUCCEEDS ###
echo "== Case 2: successful child call updates latest.md =="
setup_case

cat > "$FAKE_BIN/claude" <<'EOF'
#!/bin/bash
cat > /dev/null
cat <<'MD'
# Handoff

## Key Decisions
Did the thing.

## Open Threads
None.

## File State
n/a

## Next Steps
Ship it.
MD
exit 0
EOF
chmod +x "$FAKE_BIN/claude"

run_hook

if grep -q "Did the thing." "$HANDOFF_DIR/latest.md" 2>/dev/null; then
  pass "latest.md updated with new content on success"
else
  fail "latest.md was not updated on successful child call"
fi

rm -rf "$TMPDIR_CASE"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "ALL TESTS PASSED"
  exit 0
else
  echo "SOME TESTS FAILED"
  exit 1
fi
