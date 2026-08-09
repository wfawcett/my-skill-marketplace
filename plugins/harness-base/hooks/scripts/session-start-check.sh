#!/usr/bin/env bash
# SessionStart hook: readiness check, never blocks. Warns if this repo hasn't
# onboarded the harness-base verify contract (a `justfile` with a `verify`
# recipe — see docs/harness/00-harness-taxonomy.md, layer 7). SessionStart
# hooks aren't confirmed able to block a session at all, so this only warns.
set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)" || exit 0

if ! command -v just >/dev/null 2>&1; then
  echo "harness-base: 'just' is not installed — the Stop/SubagentStop verification gates will be skipped until it is." >&2
  exit 0
fi

if [ ! -f justfile ] && [ ! -f Justfile ]; then
  echo "harness-base: no justfile found in repo root — add one with a 'verify' recipe to enable the verification gate." >&2
  exit 0
fi

if ! just --summary 2>/dev/null | grep -qw verify; then
  echo "harness-base: justfile found but no 'verify' recipe defined — add one to enable the verification gate." >&2
  exit 0
fi

echo "harness-base: ready ('just verify' contract found)."
exit 0
