---
name: orchestration-policy
description: Model-routing policy for delegating coding tasks to harness-base's haiku-coder/sonnet-coder subagents. Use before delegating any implementation task to a subagent, and when a SubagentStop hook returns an escalation signal — decides which coder to use and what to do next.
---

# Orchestration policy (harness-base)

A subagent's own `description` field is only a soft hint for automatic
routing — it can't guarantee "try the cheap model first." This skill is
the explicit instruction that closes that gap.

## Default routing

Delegate every coding implementation task to `haiku-coder` first.

**Exception — skip straight to `sonnet-coder`** when the task itself is
flagged high-complexity up front:

- Touches auth or other security-sensitive code
- Spans multiple services/repos
- No existing pattern in the codebase to mimic
- Touches a schema/migration
- Involves concurrency

Don't waste a haiku-coder attempt on a task you can already tell is in this
list — that's what `sonnet-coder`'s own `description` is for.

## Escalation is automatic — don't re-implement it yourself

`harness-base`'s `SubagentStop` hook independently re-runs `just verify`
after every `haiku-coder` attempt — it does not trust the subagent's own
report of success. On the **first** failure (no retries), the hook blocks
and returns an instruction to escalate.

When that happens:

1. Re-delegate the **same task** to `sonnet-coder`, passing along the
   failure output the hook surfaced.
2. Do not re-delegate to `haiku-coder` again for this task — the hook
   already made the call; don't second-guess it or retry hoping for a
   different result.
3. If `sonnet-coder` also fails verification on the same task, that's a
   genuine block — surface it to the user rather than trying another
   subagent. There is no third tier.

## Why first-failure, not N-failure

This trades a bit of cost efficiency (no cheap retry on a trivially
fixable mistake) for a simpler, fully stateless hook — no per-task retry
counter to persist across subagent invocations. Deliberate choice, not an
oversight.
