# Factory plugin — design

Status: approved for planning. Approval relayed via a peer Claude session
("foreman-be") acting on the user's behalf across the whole design
conversation — noted here once as the source of every decision below,
per the session's own judgment call to proceed on relayed approval
rather than re-litigate provenance.

## Why

CHG has no native-Claude-Code implementation of a software-factory
pipeline. A working version exists, but it's personal and
non-portable: `~/.claude/skills/{intent,orchestrator,factory-onboarding}`
drive an external stack (`omp`, `cmux` panes, local `omlx` models,
`~/dev/sofware_factory/setup-workstream.sh`) that only runs on one
laptop. `harness-base` (this repo's existing plugin) already
establishes the target convention — skills + subagents via the
`Agent`/`Task` tool, no external process orchestration — and this
plugin follows it.

Inspiration: https://github.com/coleam00/ai-software-factory,
https://github.com/disler/super-simple-software-factory, and
Anthropic's "AI-native SDLC" framing
(https://claude.com/blog/the-ai-native-sdlc-playbook), adapted to CHG's
Jira-based intake and this repo's plugin conventions.

## Scope

v1 covers the full playbook: **Plan → Design → Build → Test → Deploy →
Maintain**, all six stages, for one workstream at a time. No
multi-workstream scheduling, no cross-repo coordination.

## Stage / artifact map

Resolved naming collision: the playbook's stage labels are fixed
(Plan/Design/Build/Test/Deploy/Maintain); artifacts were renamed to
avoid one name meaning two things across stages.

| Stage | Skill / agent | Artifact | Notes |
|---|---|---|---|
| Plan | `new_work` skill | `plan.md` | Was `intent.md` in the personal version; renamed so the Plan stage's own artifact is called `plan.md`. Also creates a Jira issue. |
| Design | `designer` agent | `spec.md` | Unchanged shape from the personal version's `designer`. |
| Build | `build-planner` agent (internal) + `builder` agent | `tasks.md` (internal) + code + tests | `tasks.md` is what was `plan.md` in the personal version (the build-execution breakdown) — renamed to avoid colliding with the Plan stage's `plan.md`. Not exposed as its own top-level pipeline stage; it's an internal Build sub-step, matching the Spec-Kit `tasks.md` convention already referenced in `docs/harness/01-workflow-standardization.md`. |
| Test | `tester` agent | test report / PR | Merges the personal version's `reviewer` + `verifier` into one agent. |
| Deploy | `deployer` agent | deploy record or checklist | See "Deploy in v1" below — no CD system exists to hook into yet, so this stays real but lightweight. |
| Maintain | `maintainer` agent | follow-up Jira issue | Closes the workstream: opens a monitoring/known-issues issue linked to the original, no live monitoring integration in v1. |

All artifacts for one workstream live in one accumulating folder, same
convention as the personal version:

```
./history/<slug>/plan.md
./history/<slug>/spec.md
./history/<slug>/tasks.md
```

(`slug` is chosen and confirmed with the user during `new_work`, same
as the personal `intent` skill did.)

## `new_work` skill

Replaces the personal `intent` skill; absorbs its five-slot interview
and adds three questions up front, one at a time, same interview style
(one question, wait for the answer, revisit earlier slots if a later
answer reopens them):

1. **Greenfield or brownfield** — new project, or a change to an
   existing repo?
2. **If brownfield: which repo(s)** — confirm against what's actually
   on disk/in the org, don't make the user type a path from memory.
3. **Kind of work** — bugfix, new feature, update, etc.
4. Then the five original slots: problem, proposed outcome, affected
   users/systems, constraints, open questions.

Writes `plan.md` in the same shape the personal `intent.md` used
(problem / proposed outcome / affected users and systems / constraints
/ open questions), just renamed.

**Jira integration**: creates a Story, Opportunity, or Epic via the
Atlassian MCP tools already available in this session
(`createJiraIssue` etc.). Sizing is decided by scope, but real scope
isn't known until after Design — so `new_work` creates the issue at a
best-guess level from the interview answers (work-type + rough scope
signals), and the Design stage reclassifies it (`editJiraIssue`) once
`spec.md` establishes real size. The Jira issue key gets recorded in
`plan.md`'s frontmatter/header so later stages and the orchestrator can
reference it.

**Repo readiness**: before writing anything, calls `factory-onboarding`
(ported near-unchanged from the personal version — it's already
Claude-Code-native, no cmux/omp dependency to strip). Same behavior:
checks git, `REVIEW.md`, a documented+runnable test command,
`.orchestrator/` gitignoring; reports pass/fail per check; offers to
fix; a declined fix that blocks `new_work` itself (no git) still lets
`plan.md` get written to disk, just skips branch/commit and says
plainly the orchestrator can't pick this workstream up yet.

**Handoff**: same as personal `intent` — branch `plan/<slug>`, commit
`plan.md` with message `plan: <one-line summary>`, then hand off to
`orchestrator`.

## `orchestrator` skill (reworked)

Drives all six stages for one workstream, same gating philosophy as
the personal version, reworked to run in-process instead of via
cmux/omp:

- **Stage execution**: instead of opening a cmux panel and launching
  `omp` inside a sandbox, invoke the stage's subagent directly via the
  `Agent` tool (`subagent_type: designer` / `build-planner` / `builder`
  / `tester` / `deployer` / `maintainer`). Model choice per stage comes
  from each subagent's own frontmatter (Claude Code convention, like
  `harness-base`'s `haiku-coder`/`sonnet-coder`), not a host-side
  model-role table.
- **State**: keep the workstream's own lightweight bookkeeping at
  `<repo>/.orchestrator/<slug>.json` (which stages are done, retry
  counts) — same file, no more `sandbox`/`surfaces` fields since there
  are no cmux panels or sandboxes anymore. Still gitignored (checked by
  `factory-onboarding`).
- **Gating logic**: unchanged from the personal version — evaluate each
  stage's artifact for real (read the file, check exit codes for
  Build/Test) against per-stage completeness criteria; on a shortfall
  that's plausibly fixable, re-invoke the same subagent with a specific
  follow-up and increment a retry counter; after 3 failed follow-ups on
  one stage, stop retrying and escalate to the user; on a stage
  reporting a genuine open question, stop and relay it to the user
  rather than guessing or sending a generic "continue."
- **Finishing**: after `Maintain` completes, stop. Report the PR (or
  review report), the Jira issue chain, and that nothing further
  happens automatically — no auto-merge, no new workstream.

## Deploy in v1

No CD system is named anywhere in this repo or the personal
`~/dev/sofware_factory/` setup, so `deployer` can't literally push to
production on day one. Concretely:

- If the repo's `CLAUDE.md`/`AGENTS.md` documents a deploy command
  (same convention `factory-onboarding` already checks for the test
  command), `deployer` runs it and records the result in the workstream
  folder.
- If none is documented, `deployer`'s output is a deployment checklist
  / handoff note — not a silent no-op stub, and not an invented
  command.

## Maintain in v1

`maintainer` opens a follow-up Jira issue (monitoring/known-issues)
linked to the original workstream issue, and marks the workstream done
in `.orchestrator/<slug>.json`. No live monitoring integration in v1 —
nothing exists yet to hook into.

## Testing

No unit-test surface in the traditional sense — these are skills and
subagent prompts, not library code. Verification is: run each ported
skill (`factory-onboarding`, the reworked `new_work`/`orchestrator`)
end-to-end against a throwaway scratch repo before merging, confirming
each stage produces its artifact and the gating/retry/escalation logic
actually fires (force one stage to fail twice, confirm escalation
instead of a third silent retry).

## Explicitly out of scope for v1

- Multi-workstream scheduling / parallel workstreams.
- Cross-repo coordination in one workstream.
- Live deploy pipelines or monitoring integrations that don't already
  exist in the target repo.
- Predictive model routing (same deferral as `harness-base`'s v1 plan).
