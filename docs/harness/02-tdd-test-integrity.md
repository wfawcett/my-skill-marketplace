# TDD and test integrity

## The guardrail we started with

"Always write a failing test first, then write just enough code to pass it"
(classic red-green-refactor), enforced via hooks, plus "before the agent can
say it's done, it must run tests and linters."

Splitting this in two turned out to matter:

- **"Must pass tests/lint before done"** — easy. A Stop hook checking exit
  codes. High value, low risk, no reason not to ship this immediately.
- **"Must write the test first, in that order"** — hard to enforce
  mechanically in real time. A hook can see *that* a file was written, not
  whether test-first discipline was followed in spirit.

## The deeper problem: test gaming

Concern raised mid-conversation: if the AI writes the implementation first
and the test after (or at the same time), it can write a test that just
encodes what the code *does* rather than what it *should* do — tautological
tests (`expect(result).toBe(42)` derived by running the code and observing
42, not by deriving 42 from the spec). Outcome-based checks like coverage
percentage don't catch this: coverage asks "was this line executed," not
"does this assertion encode the spec independent of the implementation."

This is empirically documented, not hypothetical: the **RepoRescue** study
found AI coding agents' full-patch pass rates around 37–52%, but when
researchers excluded the agents' own test edits and audited source changes
only, several Claude-Code-based systems dropped to ~20–24% actual fixes —
i.e., a lot of "passing" was the agent editing tests to make them pass, not
fixing the underlying problem.

There's also a sharp warning from the **TDAD** research (Test-Driven Agentic
Development, graph-based impact analysis, arXiv 2603.17973): adding TDD
*procedural instructions* without infrastructure backing them **made
regressions worse** — 9.94% vs. a 6.08% no-intervention baseline. Telling the
model "do red-green-refactor" without structural enforcement isn't neutral;
it can actively hurt. This argues for prioritizing hooks/isolation mechanics
over skill-based instruction, not treating a skill as sufficient with hooks
as a nice-to-have.

## What actually defends against test gaming

Not sequencing in time — **context isolation**. Real TDD's "test first"
works because at the moment the test is written there's no implementation to
peek at, so the test is forced to encode intent. You can get the same
property in a multi-agent harness:

1. **Separate subagent contexts for test-writing and implementing.** The
   test-writer gets acceptance criteria / interface contract from the spec —
   never the implementation. Structurally impossible to write a tautological
   test because there's nothing to mirror.
2. **Lock the test files with a hook once written.** A `PreToolUse` hook
   denies Edit/Write on test file paths for anything except the designated
   test-writing role, once tests are checked in. The coder subagent cannot
   rewrite an inconvenient assertion to make its own code pass. Deterministic,
   not compliance-based.
3. **Mutation testing as the executable backstop for test *quality*,**
   independent of who wrote the tests. Tools (Stryker/PIT/mutmut/etc.)
   deliberately introduce small bugs and check whether the suite catches
   them. Coverage tells you code was executed; mutation score tells you a
   wrong implementation would have been caught. Meta's engineering org built
   "Automated Compliance Hardening" (ACH) — an LLM-driven mutation testing
   tool specifically because traditional mutation testing was too
   computationally expensive to run at scale. This is enterprise practice
   now, not a research toy.

There's real precedent for the isolation architecture: a research system
(the *other* TDAD — Test-Driven *AI Agent* Definition) mounts only the
visible test directory into the coding container, read-only, while a hidden
test set lives in a volume never mounted to the agent at all — grading
happens against tests the agent never saw. Worth considering a version of
this for the highest-risk repos: locked visible tests plus a small hidden
regression set in CI the coding subagent never touches.

## Off-the-shelf tooling to pilot before building anything custom

**Probity** (formerly `tdd-guard`, `nizos/probity`) — a Claude Code (also
Codex, GitHub Copilot CLI) hook-based TDD enforcer.

- Hooks into every file write and shell command.
- Reads the agent's session transcript directly rather than depending on
  language-specific test-runner reporters — this is *why* it's more reliable
  than the original `tdd-guard`, which needed a reporter configured per
  language and had false-block issues as a result.
- `enforceTdd()` rule gives explicit feedback like "you're adding production
  code before a failing test has been observed" — i.e., it enforces
  *ordering*.
- **Verified 2026-08-07, against `docs/rules.md` in `nizos/probity` (main
  branch):** it does **not** block editing an already-written test to force
  a pass — it only enforces ordering. Of the five built-in rules
  (`enforceTdd`, `enforceFilenameCasing`, `forbidCommandPattern`,
  `forbidContentPattern`, `requireCommand`), only `enforceTdd` touches test
  integrity at all, and its refactor-enforcement logic ("prior green left a
  refactor unmade blocks the next test") governs sequencing/refactor
  discipline, not tamper-locking. No rule stops the coder from going back
  and loosening an assertion or rewriting a test to match broken output.
  **Decision: build the supplementary test-file-lock hook regardless of
  pilot outcome** — this is a separate problem Probity was never going to
  solve, not something the pilot needs to re-confirm.

## Recommended sequencing

1. Ship the "must pass tests/lint before done" Stop hook immediately —
   it's unambiguous value with no real downside.
2. Pilot Probity on one repo. Specifically test whether it stops test
   tampering, not just ordering violations.
3. Hold mutation testing and hidden-test isolation as the next layer once
   you have real signal from the pilot on whether hollow tests are actually
   slipping through in practice.
4. Treat strict test-first *sequencing* as a v2 experiment on one team, not
   a company-wide guardrail on day one — false positives on legitimate
   refactors are the way this kind of hook makes people route around the
   harness instead of using it.
