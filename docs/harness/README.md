# Coding Harness — Design Notes

This folder is the working record of a design conversation about building an
"AI SDLC" coding harness on top of Claude Code for CHG's engineering org. It
exists to get traction on AI-assisted development with consistent
conventions, guardrails, and traceability — not to hand everyone Claude Code
and hope for the best.

Owner / DRI (Directly Responsible Individual): William Fawcett.

## Why this exists

The starting problem: engineering has no shared coding conventions for
AI-assisted work, so output quality and practice vary wildly by individual.
The goal is to define a harness — the ecosystem of context, structure, and
guardrails around the model — that makes AI-generated code consistently
enterprise-grade, not just demo-grade.

## The seven things a real harness has to own

1. **Context grounding** — actual conventions injected per task, not generic
   best practices.
2. **Staged generation, not one-shot** — plan → scaffold → implement → test →
   self-review, with intermediate artifacts a human can check.
3. **Verification loops that are executable, not vibes** — build/test/lint/
   security scans, with failures fed back automatically.
4. **Guardrails and policy** — deterministic checks (regex/AST/static
   analysis) for things that must never happen, not "ask the model to
   remember."
5. **Adversarial review, not self-grading** — a model checking its own work
   is weak; use a differently-framed second pass.
6. **Traceability/audit** — a record of what was generated from what spec,
   checked against what, approved by whom. Matters a lot in a regulated
   (healthcare) environment.
7. **Human gate at the right altitude** — approve the plan/interface before
   implementation, and the final diff before merge. Not the 50 moments in
   between.

## How this maps onto Claude Code's actual primitives

Anthropic's own guidance (see `08-research-notes-and-sources.md`) frames the
harness as five extension points, built in this order:

**CLAUDE.md → Hooks → Skills → Plugins → MCP servers**, with LSP integrations
and subagents as advanced/later additions.

Rough mapping to the seven pillars:

| Pillar | Native primitive | Gap you have to design |
|---|---|---|
| Context grounding | CLAUDE.md, Skills | Static injection, not per-task retrieval |
| Staged generation | Plan Mode | Distinct gated artifacts (spec/plan/tasks) aren't built-in |
| Verification loops | Hooks (PostToolUse/Stop) | You write the actual checks |
| Guardrails | Hooks (PreToolUse), permissions | You write the actual policy |
| Adversarial review | Subagents | Multi-pass "refute" framing is a harness pattern you design |
| Traceability/audit | Session transcripts (unstructured) | Basically nothing native — biggest build item for a regulated shop |
| Human gate | Plan Mode approval, PR review | Mostly already solved by process |

## Contents of this folder

- `01-workflow-standardization.md` — Spec-Kit vs. Superpowers, and the
  combined pattern (via the `superspec` bridge) that resolves the tension
  between execution speed and audit-trail durability.
- `02-tdd-test-integrity.md` — why "just enforce TDD" isn't enough, the test-
  gaming problem, and the isolation/lock/mutation-testing defenses that
  actually hold up.
- `03-model-routing.md` — the Opus/Fable-plans, Haiku-codes cost model, and
  the escalation design so cheap-by-default doesn't mean bad-on-hard-tasks.
- `04-lsp-and-code-navigation.md` — LSP plugins for our actual stack, and
  where a cross-repo knowledge graph (Graphify) would vs. wouldn't help.
- `05-marketplace-and-harness-base-plugin.md` — the internal plugin marketplace
  plan and what the `harness-base` plugin should and shouldn't contain at launch.
- `06-governance.md` — the DRI model, committee structure, and the two
  separate review cadences (standards content vs. rule/config health).
- `07-v1-harness-plan.md` — the concrete, intentionally narrow v1 scope,
  including what's explicitly deferred and why.
- `08-research-notes-and-sources.md` — the external research pulled in along
  the way (tools, papers, blog posts) with links.
- `99-open-questions.md` — decisions not yet made; use this as the starting
  point for the next conversation.

## Status

This is a design conversation, not yet an implementation. Nothing here has
been built, piloted, or approved. Treat every recommendation in this folder
as a proposal for the lead-dev committee, not a shipped decision.
