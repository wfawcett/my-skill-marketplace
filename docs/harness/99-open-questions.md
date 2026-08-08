# Open questions / next steps

Nothing below has been decided. This is the starting point for the next
conversation, not a backlog with assigned owners.

## Immediate decisions needed

1. **Pilot repo selection — decided 2026-08-07.** `chg-wade-agent-service`
   (Python/FastAPI, Clean Architecture) is the first pilot repo, worked in a
   sandbox clone rather than the primary working copy. Superspec bridge
   pilot deferred — not being pursued right now. First build in this repo:
   `pyright-lsp` plugin (already enabled), `repo-explorer` and
   `python-builder` subagents (both `model: haiku`), and a `Stop` hook
   running `make lint` + `make test-unit` gated on changed files, guarded
   against re-entry loops. See `.claude/agents/` and `.claude/hooks/` in
   that repo.
2. **Probity tamper-lock verification — answered 2026-08-07.** Confirmed
   against `nizos/probity`'s `docs/rules.md`: it only enforces write-order,
   not tamper-locking. See `02-tdd-test-integrity.md` for the detail.
   Decision: build the supplementary test-file-lock hook (`PreToolUse` deny
   on Edit/Write to locked test paths) regardless of any future Probity
   pilot — it's a separate problem Probity doesn't address. Not yet built.
3. **Plugin version pinning policy.** Does `chg-base` ship with a pinned
   version in each consuming repo's config (safe, but requires an explicit
   "please update" push from the DRI), or float to latest (true one-place-
   update propagation, but silent drift risk if nobody's watching)? This
   needs an explicit decision, not a default.
4. **Committee composition.** Confirm whether a security/compliance seat
   gets added to the monthly lead-dev meeting, given the healthcare
   regulatory context.

## Content to write before/around the first committee meeting

- `temporal-determinism` skill — the actual list of non-deterministic APIs
  to flag inside workflow code, plus examples of the activities/workflows
  boundary done right and wrong in our codebase.
- `security-review` skill content (adapt from the existing `/security-review`
  skill if one is already in use).
- The `haiku-coder` / `sonnet-coder` subagent definitions and the escalation
  policy instruction (CLAUDE.md or a skill) wiring them together.

## Deferred until there's real signal

- Predictive complexity tagging for model routing (v2 — needs real Haiku-
  failure data first).
- Mutation testing / coverage-diff enforcement (wait on Probity pilot
  results).
- Graphify cross-repo pilot (wait until the cross-repo interaction problem
  is actually being worked, not before).
- Hidden-test isolation architecture for the highest-risk repos.

## Bigger, not-yet-scoped questions

- What does "done" look like for a change to `chg-base` or a shared hook —
  does it go through a lightweight review, and who's the second approver
  besides the DRI?
- How does the rule/config health review (quarterly-ish, see
  `06-governance.md`) actually get scheduled and staffed — is it part of the
  monthly meeting on some cadence, or a separate session?
- Traceability/audit: once Spec-Kit's artifacts exist, where do they live
  long-term, and does anything need to happen to make them satisfy an
  actual compliance/audit request, or is "they're in the repo history"
  sufficient?
