# Model routing: cost control without quality collapse

## The ask from leadership

Use Opus/Fable for planning, Haiku whenever possible for the actual coding,
to control cost. Haiku runs at roughly 15x cheaper per token than Opus.

## Why a blanket "coding = Haiku" rule is risky

Haiku is cheaper and worse at first-pass correctness. The trade only nets out
ahead when a tight, deterministic verification loop (the test/lint Stop hook
from `02-tdd-test-integrity.md`) catches and corrects its mistakes
automatically. On the harder slice of changes — concurrency, tricky business
logic, anything touching cross-service boundaries — Haiku failing repeatedly
and retrying can burn more tokens than one Sonnet pass would have, and worse,
burns developer patience. A few visible "the AI churned for 10 minutes and
produced garbage" episodes is the fastest way to kill adoption.

## The routing design

Two levers, run together, not a single classifier call (which itself costs
tokens and can be wrong):

### 1. Predictive tagging, piggybacked on planning (free)

The Opus/Fable planner is already producing a task breakdown before coding
starts. Have it tag each task's complexity as part of that output — not a
separate classification pass, just an extra field filled in while it's
already reasoning about the work. Concrete tripwires to tag "high": touches
auth/security-sensitive code, spans multiple services/repos, no existing
pattern in the codebase to mimic, touches a schema/migration, concurrency.
Anything tagged high skips Haiku entirely and goes straight to Sonnet.

### 2. Reactive escalation as the safety net

A subagent can't upgrade itself mid-task — the decision lives one level up,
in whichever agent is delegating. Concretely:

- Define two coding subagent variants — `haiku-coder` and `sonnet-coder` —
  pinned to different models.
- Orchestrator policy (in CLAUDE.md or a skill): delegate coding to
  `haiku-coder` by default; if it reports back having failed the test/lint
  gate twice, re-delegate the same task to `sonnet-coder` with the
  accumulated failure context.
- Cap retries (e.g. 2) so a genuinely hard task doesn't burn Haiku attempts
  in a loop before falling through.

This composes directly with the "must pass tests before done" guardrail —
that gate is what generates the failure signal the orchestrator escalates
on. Two things you already wanted, wired into each other.

This retry-then-escalate shape (try cheap → retry with feedback → escalate
to a bigger model → fall back to human review as last resort) is a
documented production pattern for agent fault tolerance generally. Applying
it specifically to *coding cost control* isn't something found already
written up elsewhere — this is original design work for this use case, not
an adopted solution.

## Known configuration lever

`CLAUDE_CODE_SUBAGENT_MODEL` — an env var that force-pins every subagent in
a session to one model, org-wide. Blunter than the routing above; useful as
an emergency cost-ceiling / compliance switch, not as the default policy
mechanism.

## v1 scope (see `07-v1-harness-plan.md`)

Ship the simple reactive-only version first: default to `haiku-coder`,
escalate to `sonnet-coder` after 2 failed test/lint cycles. Hold the
predictive complexity tagging for v2, once there's real failure data to
tune the tripwires against.
