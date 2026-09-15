---
name: factory-onboarding
description: Audit whether a repo is ready to run in the software factory pipeline (git setup, REVIEW.md, a documented and runnable validation command, ignored orchestrator state). Reports pass/fail per check and offers to fix anything missing. Use when the user asks to onboard a repo to the factory, invokes /factory-onboarding, or before running /new_work in a repo for the first time.
---

Run every check below against the current repo, in order, and report a
pass/fail line for each one before offering to fix anything. Don't fix
silently — a repo that "became" factory-ready without the user seeing
what changed is worse than one that stayed not-ready with a clear
reason why.

Format the report like this, one line per check:

```
[PASS] git repository
[FAIL] REVIEW.md — missing
[PASS] validation command — documented and runs clean (make test)
[FAIL] .orchestrator/ — not in .gitignore
```

Then, for every `FAIL`, ask whether to fix it now (batch the asks into
one round — this repo either gets fully onboarded in one pass or the
user tells you which gaps to leave for later).

## Check 1 — git repository

```bash
git rev-parse --is-inside-work-tree
```

Fail if this errors. Fix: offer `git init`, same as the `new_work`
skill does. If the user is running this skill *before* `new_work`,
doing it here means `new_work` won't need to ask again.

## Check 2 — `REVIEW.md` at the repo root

Fail if `<repo>/REVIEW.md` doesn't exist. The `tester` agent refuses
to invent one, so a missing `REVIEW.md` silently kills the pipeline at
its Test stage — catch it here instead, before any subagent runs.

Fix: don't write a generic template and call it done — a copy-pasted
`REVIEW.md` with no repo-specific content is barely better than
missing. Ask three questions, one at a time:

```
❓ **Passes** — Besides Bugs and Security (always included), does this
repo need a Compliance pass, an Accessibility pass, a Performance pass,
or none of those? Name the ones that matter here.

➡️ Compliance only, since spec.md/tasks.md compliance is the pipeline's
own audit trail — the others are worth adding later if you're seeing
review misses in those areas.

❓ **What "Important" means here** — what would actually break behavior,
leak data, or breach policy in *this* repo specifically? (e.g. a
frontend repo might flag "new PII field rendered without redaction";
a payments service might flag "money handled as float instead of a
fixed-point type.")

➡️ (no default — this is genuinely repo-specific, don't guess)

❓ **What to skip** — anything CI already enforces (a linter, a type
checker) that the review pass shouldn't repeat, and any generated
paths (build output, codegen) that shouldn't be reviewed at all?

➡️ Whatever the repo's own lint/build config already covers — check
before answering rather than asking the user to enumerate it themselves.
```

Write the answers into `REVIEW.md` in this shape:

```markdown
# Review instructions
## Passes
Run these passes and tag each finding with its pass:
- Bugs: logic errors, broken edge cases, subtle regressions
- Security: injection risks, authentication gaps, PII in logs
<any additional passes from the answer above>
## What Important means here
<the repo-specific answer above>
## Cap the nits
Report at most five nits per review; summarize the rest as a count.
## Do not report
<generated paths and CI-covered items from the answer above>
```

## Check 3 — a documented, runnable validation command

This has two independent halves — both must pass, and "documented" without
"runs clean" is a false pass:

**Documented**: `CLAUDE.md` or `AGENTS.md` at the repo root has a
Commands section naming at least a test command (build and lint are
worth having too, but test is non-negotiable — `builder` and `tester`
both depend on being able to run one). If neither file exists, or
exists without a Commands section, that's a fail.

**Runs clean**: actually run the documented test command right now,
in this repo, and check its exit code. A documented command that fails
or doesn't exist on disk is worse than an undocumented one — it will
send `builder` down a path that looks verified but isn't. If the repo
has no tests to run yet (genuinely empty greenfield repo), that's a
fail with a specific note, not a pass — say so and don't wave it
through.

Fix, if the command is missing or wrong: don't guess the test runner
from the ecosystem alone (e.g. don't assume `npm test` for every
Node repo — check `package.json` scripts first). Find the actual
command, run it to confirm it exits 0, then write it into `CLAUDE.md`
(create it via `/init`-style generation if it doesn't exist yet, or
append a Commands section if it exists without one):

```markdown
## Commands
- Test: <actual command> (must exit 0; this is what `builder` runs before reporting done)
```

Fix, if the repo genuinely has no tests: this isn't something to
paper over. Tell the user plainly that `builder`'s feedback loop
depends on a real test command, and ask whether to scaffold a minimal
one (matching the repo's existing test runner if one is configured, or
asking which runner to set up if none is) before continuing.

## Check 4 — `.orchestrator/` is gitignored

```bash
grep -qxF '.orchestrator/' .gitignore 2>/dev/null
```

Fail if absent. Fix: append `.orchestrator/` to `.gitignore` (create
the file if it doesn't exist). This is the `orchestrator` skill's own
host-side bookkeeping (which stage is done, retry counts) — it has no
meaning outside this workstream's current run and should never land in
a commit.

## Finishing

Once every check passes (either it did originally, or the user
accepted the fix), say so plainly and name what's now true: git is set
up, `REVIEW.md` exists and is repo-specific, the test command is
documented and was just run successfully, `.orchestrator/` won't leak
into commits. This repo is ready for `/new_work`.

If the user declined a fix, say plainly which check is still failing
and what breaks downstream because of it (which stage will refuse to
run, or run against a false assumption) — don't silently let them walk
into a pipeline that's going to stall three stages in for a reason
they were told about here.
