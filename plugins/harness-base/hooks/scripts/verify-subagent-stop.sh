#!/usr/bin/env bash
# SubagentStop hook (matcher: haiku-coder). Re-runs `just verify` itself
# rather than trusting the subagent's own report of success. On failure,
# blocks and signals escalation to sonnet-coder — first-failure escalation,
# no retry counter, no state file (see docs/harness/00-harness-taxonomy.md).
set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" || exit 0

stdin_json=$(cat)
if echo "$stdin_json" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

if ! command -v just >/dev/null 2>&1 \
  || { [ ! -f justfile ] && [ ! -f Justfile ]; } \
  || ! just --summary 2>/dev/null | grep -qw verify; then
  exit 0
fi

if [ -z "$(git status --porcelain)" ]; then
  exit 0
fi

verify_out=$(just verify 2>&1)
verify_status=$?

if [ "$verify_status" -ne 0 ]; then
  echo "verify-subagent-stop: haiku-coder failed 'just verify' — escalate this task to sonnet-coder with the failure output below. Do not retry haiku-coder." >&2
  echo "--- just verify output ---" >&2
  echo "$verify_out" >&2
  exit 2
fi

exit 0
