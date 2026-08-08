# Workflow standardization: Spec-Kit vs. Superpowers

## The goal

Get the team into the habit of using a *formal* workflow for AI-assisted
changes, consistently, rather than everyone improvising their own approach
with Claude Code. Two candidate frameworks were considered:

- **GitHub Spec-Kit** — spec-driven. Durable, human-readable artifacts:
  `constitution.md → spec.md → plan.md → tasks.md`. Explicit, deterministic
  triggering (you type `/speckit.plan`). Extension model is catalog-driven.
- **Superpowers** — skill-driven. Feels like an operating system the agent
  inhabits rather than a CLI you drive. Skills auto-fire when their
  description matches the situation. Bakes in TDD, worktrees, subagents, and
  review. Extension model is author-driven (write the next skill yourself).

Initial preference was Superpowers, for the lighter weight and faster
iteration.

## The tension that surfaced

Superpowers' lightweight, flow-optimized design doesn't give you a durable
audit trail. Spec-Kit's artifacts (`spec.md`, `plan.md`, `tasks.md`) are
exactly the traceability record pillar 6 requires — "generated from what
spec, checked against what" — which matters specifically because CHG is in a
regulated (healthcare) environment. Picking Superpowers alone means
implicitly deciding the audit trail is a separate problem to solve later.

## The resolution: don't choose, combine

This is a solved problem in the Claude Code plugin ecosystem, not something
to invent from scratch. The common pattern:

- **Spec-Kit owns governance** — the durable artifacts: constitution → spec
  → plan → tasks. This is the audit trail.
- **Superpowers owns execution** — once `tasks.md` exists, it runs with
  worktree → TDD (red-green-refactor) → subagent-driven execution → code
  review → finish-branch.

The handoff point is `tasks.md`. A single line bridges the two systems:

> "Implementation of any task list MUST follow the Superpowers workflow:
> worktree → TDD (red-green-refactor) → subagent-driven execution → code
> review → finish-branch. Do not re-plan — the task list is the contract."

### The `superspec` bridge (third-party, evaluate before adopting wholesale)

`WangX0111/superspec` implements this handoff directly as a Claude Code
plugin layered on Spec-Kit:

- Adds 5 commands: `/speckit.superspec.status`, `.brainstorm`, `.tasks`,
  `.execute`, `.review` — extending Spec-Kit's core commands
  (constitution/specify/plan/tasks/checklist), not replacing them.
- Governance layer: `.specify/memory/constitution.md` (project principles)
  plus an auto-managed `superpowers.yml` that detects installed Superpowers
  skills.
- Per-feature layer: `specs/NNN-feature-name/{spec.md, plan.md, tasks.md,
  progress.yml, checklist-*.md}`.
- `tasks.md` carries "execution markers" that route each task to the right
  Superpowers skill (`writing-plans`, `test-driven-development`,
  `subagent-driven-development`, `executing-plans`).
- `progress.yml` tracks completion per task, so sessions are resumable.
- Human approval gates are preserved at every phase transition — you decide
  when to advance, not the agent.
- If Superpowers skills aren't installed, built-in fallback protocols handle
  brainstorming/planning/review instead of failing.

Full flow:

```
Constitution → Specify → Brainstorm ↔ Plan → Tasks → Execute → Review
                              ↑___________↓
                          (iterate until spec solidifies)
```

### Adoption plan

`superspec` is a third-party bridge, not blessed by either upstream project.
Treat it as: **pilot on one low-stakes repo first.** If it proves flaky, the
fallback is the hand-rolled one-liner convention above, which the community
already validated as sufficient without the bridge tooling.

There's also an open discussion thread in Spec-Kit's own GitHub repo
(`github/spec-kit` discussion #1889) about this exact integration, worth
reading before committing to an approach.
