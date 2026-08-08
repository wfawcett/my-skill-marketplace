# v1 harness plan

Deliberately narrow — enough to establish the pattern and prove it works,
not everything discussed in the design conversation. Resist shipping all of
it at once. Several pieces below are explicitly "pilot on one repo," not
"roll out everywhere."

## Layer 1: Foundation (every repo, immediately, no marketplace needed)

- **Hierarchical CLAUDE.md** — root pointer file per repo, plus a
  subdirectory CLAUDE.md wherever a service has its own test/lint/build
  commands. Matches both Anthropic's guidance and our microservice reality.
- **One Stop hook: tests + linter must pass before the agent can call a task
  done.** Deterministic, no state tracking, just checking exit codes. See
  `02-tdd-test-integrity.md`.
- **Two LSP plugins installed org-wide: `pyright-lsp` and `typescript-lsp`.**
  Zero custom building — covers all three language stacks (JS, TS, Python).
  See `04-lsp-and-code-navigation.md`.

## Layer 2: `harness-base` plugin v1 (sparse, on purpose)

- **`temporal-determinism` skill** — the non-deterministic-API tripwires for
  Temporal workflow code. Prioritized because it's a correctness hazard
  (breaks on replay in production), not a style preference, and generic
  model knowledge won't catch it. Write this before the first committee
  meeting.
- **`security-review` skill** — the standing example from the original ask.
- **Two subagent definitions: `haiku-coder` and `sonnet-coder`.** v1 policy
  is the simple version: default every implementation task to
  `haiku-coder`; escalate to `sonnet-coder` after 2 failed test/lint cycles.
  No predictive complexity tagging yet — that's v2, once there's real
  failure data to tune it against. See `03-model-routing.md`.

Nothing else goes into `harness-base` yet — no Graphify, no mutation testing, no
coverage-diff enforcement.

## Layer 3: Two narrow pilots, one repo each (not org-wide)

- **Workflow bridge pilot** — Spec-Kit + Superpowers + `superspec` on one
  repo, so the `tasks.md` handoff to TDD/subagent execution gets exercised
  with real work, human approval gates preserved at each phase. Fallback if
  `superspec` proves flaky: the one-line convention alone (see
  `01-workflow-standardization.md`).
- **TDD enforcement pilot** — Probity on one repo, specifically checking
  whether it blocks *editing* an already-written test to force a pass, or
  only enforces ordering. That answer determines whether a supplementary
  test-lock hook is needed before this goes wider. See
  `02-tdd-test-integrity.md`.

## Layer 4: Governance

- William as DRI, monthly lead-dev meeting, plus a security/compliance seat
  given the healthcare context.
- Two separate review clocks: monthly for standards content, ~quarterly for
  rule/config health. See `06-governance.md`.

## Explicitly deferred, and why

- **Graphify** — wait for the cross-repo interaction problem to actually
  bite before adopting a tool built for it.
- **Predictive complexity tagging** for model routing — start reactive-only,
  add prediction once real Haiku-failure patterns exist to design against.
- **Mutation testing / coverage-diff enforcement** — wait to see whether the
  Probity pilot plus the existing Stop hook already catch hollow tests in
  practice before adding this layer.

## Rough sizing

Layer 1 plus the `temporal-determinism` skill content is roughly a two-to-
three-week setup solo. The pilots in Layer 3 are where the real time goes —
you're watching how they behave in practice, not just installing them.
