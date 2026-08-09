#!/usr/bin/env bash
# Stop hook: run `just verify` before letting the agent claim a task done.
# Exit 2 blocks the stop and feeds stderr back to the model as feedback.
set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" || exit 0

stdin_json=$(cat)
if echo "$stdin_json" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

# Repo hasn't onboarded the contract yet — SessionStart already warned about
# this. Don't block work in a repo that has no `just verify` to run.
if ! command -v just >/dev/null 2>&1 \
  || { [ ! -f justfile ] && [ ! -f Justfile ]; } \
  || ! just --summary 2>/dev/null | grep -qw verify; then
  exit 0
fi

# Nothing changed this turn (e.g. a read-only question) — skip.
if [ -z "$(git status --porcelain)" ]; then
  exit 0
fi

verify_out=$(just verify 2>&1)
verify_status=$?

if [ "$verify_status" -ne 0 ]; then
  echo "verify-stop: do not report this task as done yet — 'just verify' failed." >&2
  echo "--- just verify output ---" >&2
  echo "$verify_out" >&2
  exit 2
fi

exit 0
