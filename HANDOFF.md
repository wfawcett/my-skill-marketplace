# Handoff — start here

Continuity note for whoever (including a fresh Claude Code session) picks
up work in this repo next. Written 2026-08-08, DRI: William Fawcett.

## What this repo is

A public, personal (`wfawcett`, not `chghealthcare`) Claude Code plugin
marketplace, prototyping an "AI SDLC" coding harness for CHG's engineering
org. Public/personal is a deliberate, temporary choice — see "Open
decisions" below.

## Status

- **`harness-base` plugin: skeleton only, no real content yet.**
  `plugins/harness-base/.claude-plugin/plugin.json` exists and validates,
  but has no skills/agents/hooks wired in. The v1 content it should carry
  (`temporal-determinism` skill, `security-review` skill, `haiku-coder` /
  `sonnet-coder` subagents) is scoped in `docs/harness/07-v1-harness-plan.md`
  but not yet built. **This is the next real piece of work.**
- **`docs/harness/`** — the full design conversation that produced this
  plan (7 topic files + open questions + research notes). Read
  `docs/harness/README.md` first, then `docs/harness/99-open-questions.md`
  for what's still undecided.
- **Was named `chg-base` until 2026-08-08**, renamed to `harness-base` to
  strip the company identifier out of the plugin/marketplace *names*
  specifically. The descriptive prose ("CHG harness baseline...") in
  `plugin.json`/`marketplace.json` still names CHG — that wasn't in scope
  of the rename, only flagging in case it should be revisited.

## Related repo: the pilot

`~/dev/chg-wade-agent-service` — a clean clone of
`chghealthcare/chg-wade-agent-service`, separate from the real, active work
copy at `~/dev/wade/chg-wade-agent-service` (do not confuse the two; the
`wade/` one has live feature-branch work and must not be touched by
harness experiments).

- Branch `feature/harness-pilot-subagents-and-hook`, **not pushed to
  GitHub yet, no PR** — that's a deliberate pause point, not an oversight.
- Carries two subagents (`python-builder`, `repo-explorer`, both
  `model: haiku`) and a `Stop` hook (`.claude/hooks/verify-before-stop.sh`)
  that runs `make lint` + `make test-unit` before letting the agent claim
  a task done — gated so it skips no-op turns and doesn't loop on itself.
- These two subagents are **repo-specific** (bake in this repo's Clean
  Architecture rules) — they do not belong in the generic `harness-base`
  plugin. `haiku-coder`/`sonnet-coder` (generic, in `harness-base`) are a
  separate, not-yet-built pair.
- **Known bug, not fixed:** `tests/unit/test_job_model_conversion.py:30`
  has a pre-existing `E501` on the real `chghealthcare/chg-wade-agent-service`
  `main` branch. It blocks the new Stop hook on any turn touching
  `src`/`tests` until someone fixes it upstream. A one-line wrap; not done
  here because it was out of scope for the migration task that found it.

## Open decisions (unchanged from `docs/harness/99-open-questions.md`)

1. Plugin version pinning policy for `harness-base` — pinned per-repo vs.
   floating. Not decided.
2. Committee composition — whether a security/compliance seat joins the
   monthly lead-dev meeting. Not decided.
3. **Org migration** — this repo is expected to move from personal/public
   to the `chghealthcare` org at some future point. No date, no trigger
   condition set. Whoever picks this up should treat that as a live
   open item, not something already scheduled.
4. Superspec (Spec-Kit + Superpowers bridge) pilot — explicitly deferred,
   not part of any current plan.

## Suggested next steps, roughly in order

1. Build `harness-base` v1 content per `docs/harness/07-v1-harness-plan.md`
   Layer 2 (`temporal-determinism` skill, `security-review` skill,
   `haiku-coder`/`sonnet-coder` subagents).
2. Once `harness-base` has real content, install it into the pilot repo
   (`~/dev/chg-wade-agent-service`) via `extraKnownMarketplaces` +
   `enabledPlugins` — this is the actual mechanic Layer 2 needs proven,
   not just files copied in by hand.
3. Decide whether/when to push the pilot's feature branch and open a PR
   against the real `chg-wade-agent-service` repo.
4. Fix the pre-existing `E501` on that repo's real `main` (see above) —
   independent of everything else, just needs doing.

## Where the restructuring work itself is recorded

If you need the history of *how* this split happened (not the harness
design itself): `wfawcett/test-sprawl`, `docs/superpowers/specs/2026-08-08-*`
and `docs/superpowers/plans/2026-08-08-*`. Not needed for day-to-day work
here — `test-sprawl` is retired as a working repo.
