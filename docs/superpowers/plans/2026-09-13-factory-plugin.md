# Factory Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a `factory` plugin in this marketplace implementing the
Plan → Design → Build → Test → Deploy → Maintain software-factory
pipeline as native Claude Code skills and subagents.

**Architecture:** Two skills (`new_work`, ported `factory-onboarding`)
plus a reworked `orchestrator` skill that drives six subagents
(`designer`, `build-planner`, `builder`, `tester`, `deployer`,
`maintainer`) via the `Agent` tool, one per pipeline stage. All state
and artifacts live in the target repo (`history/<slug>/*.md`,
`.orchestrator/<slug>.json`), not in this plugin.

**Tech Stack:** Claude Code skills (Markdown + frontmatter), Claude Code
subagents (Markdown + frontmatter), Atlassian MCP tools (`createJiraIssue`,
`editJiraIssue`, `createIssueLink`) for Jira integration.

**Spec:** `docs/superpowers/specs/2026-09-13-factory-design.md`

## Global Constraints

- Plugin name is `factory`, kebab-case, unique in this repo's
  `.claude-plugin/marketplace.json`.
- No dependency on `cmux`, `omp`, `omlx`, or any host-side sandbox
  script — everything runs via Claude Code's own `Agent`/`Task` tool.
- Artifact filenames are exactly: `plan.md`, `spec.md`, `tasks.md`,
  `deploy.md`, `maintain.md` (per the spec's stage/artifact table) —
  never `intent.md` (the old personal-version name).
- Jira integration uses only the Atlassian MCP tools already available
  in-session (`createJiraIssue`, `editJiraIssue`, `createIssueLink`) —
  no new dependency, no direct REST calls.
- Subagent frontmatter follows this repo's existing convention (see
  `plugins/harness-base/agents/haiku-coder.md`): `name`, `description`,
  `model` (`haiku`/`sonnet`), `tools` (capitalized Claude Code tool
  names), plain-prose body — not the personal version's `@role`/`spawns`
  frontmatter.

---

## Task 1: Plugin manifest and marketplace registration

**Files:**
- Create: `plugins/factory/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

**Interfaces:**
- Produces: a plugin named `factory`, version `0.1.0`, discoverable by
  every later task's files living under `plugins/factory/`.

- [ ] **Step 1: Create the plugin manifest**

```json
{
  "name": "factory",
  "description": "CHG software-factory pipeline: Plan -> Design -> Build -> Test -> Deploy -> Maintain, driven by Claude Code skills and subagents.",
  "version": "0.1.0",
  "author": {
    "name": "William Fawcett"
  }
}
```

- [ ] **Step 2: Register the plugin in the marketplace**

Add a second entry to the `plugins` array in
`.claude-plugin/marketplace.json`, alongside the existing `harness-base`
entry:

```json
    {
      "name": "factory",
      "source": "./plugins/factory",
      "description": "CHG software-factory pipeline: Plan -> Design -> Build -> Test -> Deploy -> Maintain, driven by Claude Code skills and subagents.",
      "version": "0.1.0",
      "author": {
        "name": "William Fawcett"
      }
    }
```

- [ ] **Step 3: Verify the manifest is valid JSON and matches the schema**

Run: `python3 -m json.tool plugins/factory/.claude-plugin/plugin.json && python3 -m json.tool .claude-plugin/marketplace.json`
Expected: both print reformatted JSON with no error.

- [ ] **Step 4: Commit**

```bash
git add plugins/factory/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "factory: add plugin manifest and marketplace entry"
```

---

## Task 2: `factory-onboarding` skill (ported)

**Files:**
- Create: `plugins/factory/skills/factory-onboarding/SKILL.md`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: a Skill invocable as `factory-onboarding`, called by
  `new_work` (Task 3) before it writes anything.

- [ ] **Step 1: Create the skill file**

```markdown
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
```

- [ ] **Step 2: Verify the ported content against the spec's renames**

Run: `grep -n "intent\|planner\b" plugins/factory/skills/factory-onboarding/SKILL.md`
Expected: no output (the personal version's `intent`/`planner`
references have all been renamed to `new_work`/`tester` per the spec's
stage/artifact table).

- [ ] **Step 3: Smoke-test the bash checks in a scratch repo**

```bash
mkdir -p /tmp/factory-smoke && cd /tmp/factory-smoke && git init -q
git rev-parse --is-inside-work-tree   # Check 1: should print "true"
test -f REVIEW.md; echo "REVIEW.md exit: $?"   # Check 2: should be 1 (missing)
grep -qxF '.orchestrator/' .gitignore 2>/dev/null; echo ".gitignore exit: $?"   # Check 4: should be 1 (missing)
cd - && rm -rf /tmp/factory-smoke
```
Expected: `true`, `REVIEW.md exit: 1`, `.gitignore exit: 1` — confirms
the check commands correctly detect a fresh, not-yet-onboarded repo.

- [ ] **Step 4: Commit**

```bash
git add plugins/factory/skills/factory-onboarding/SKILL.md
git commit -m "factory: add factory-onboarding skill"
```

---

## Task 3: `new_work` skill

**Files:**
- Create: `plugins/factory/skills/new_work/SKILL.md`

**Interfaces:**
- Consumes: `factory-onboarding` (Task 2, invoked via the Skill tool).
- Produces: `history/<slug>/plan.md` in the target repo, a Jira issue
  key recorded in its `Jira:` line, and a handoff to `orchestrator`
  (Task 10).

- [ ] **Step 1: Create the skill file**

```markdown
---
name: new_work
description: Interview the user to scope new work (greenfield vs brownfield, affected repo(s), kind of work) and sharpen it into a committed plan.md, the entry artifact for the software factory pipeline (plan.md -> spec.md -> tasks.md -> build -> test -> deploy -> maintain). Creates a matching Jira issue. Use when the user wants to propose a new feature, start a new workstream, or invokes /new_work.
---

Interview the user relentlessly until `plan.md` is fully settled. This
is `grilling` (see that skill if installed) narrowed to a fixed target
shape instead of an open-ended design tree.

## The interview

Ask one question at a time, wait for the answer, and revisit an
earlier answer if a later one reopens it. Work through these in order:

1. **Greenfield or brownfield** — is this a new project, or a change to
   a repo that already exists?
2. **Affected repo(s)** (brownfield only) — which repo(s) does this
   touch? Look at what's actually on disk / in the org first and put
   concrete names in front of the user to confirm, rather than asking
   them to recall paths from memory.
3. **Kind of work** — bugfix, new feature, update, or something else?
4. **Problem** — what's broken or missing today, and for whom?
5. **Proposed outcome** — what does the world look like once this ships?
6. **Affected users and systems** — who and what does this touch?
7. **Constraints** — hard limits: policy, security, no-new-dependency,
   deadline, whatever is non-negotiable.
8. **Open questions** — anything genuinely unresolved that the next
   stage (`designer`) must answer, not you guessing at it now.

Format each question like `grilling` does:

```
❓ **<slot>** — <question, plain language, no jargon>

➡️ <your recommended answer, if you have one — silence if you genuinely don't>
```

**Facts are your job, not the user's.** Before asking about affected
repos or systems, read the actual repository/org structure and put
concrete names in front of the user to confirm or correct. Dispatch a
read-only sub-agent for this if it takes more than a glance. Never ask
the user a question you could answer yourself by reading the repo.

**Push back on vague answers.** "Make it faster" is not a proposed
outcome. "Users are affected" is not an affected-users answer. If an
answer is too vague for the next stage (`designer`) to act on without
guessing, say so and ask again.

The session is done when every slot is settled and the user confirms
the draft below matches what they meant. Do not write or commit
anything before that confirmation.

## Repo readiness check

Before writing anything, call the Skill tool with `factory-onboarding`.
It checks git setup, `REVIEW.md`, a documented and runnable validation
command, and `.orchestrator/` gitignoring, and offers to fix whatever's
missing. If the user declines a fix that blocks this skill specifically
(no git), still write `plan.md` to disk (per below) but skip the branch,
commit, and Jira steps entirely, and say plainly that the workstream
can't be picked up by the orchestrator until git is set up. A declined
`REVIEW.md`/validation-command fix doesn't block this skill — it will
block later stages, and `factory-onboarding` already said so.

## Output shape

Pick `<slug>`, a short, filesystem-safe, hyphenated description of the
work (e.g. `claims-status-self-service`), and confirm it with the user.
Every artifact for this workstream lives in one folder that accumulates
over the pipeline's lifetime — this skill only ever writes the first
file into it:

```
./history/<slug>/plan.md      (this skill writes this)
./history/<slug>/spec.md      (designer writes this, later)
./history/<slug>/tasks.md     (build-planner writes this, later)
```

Create `./history/<slug>/` if it doesn't exist. Write `plan.md` inside
it in exactly this shape:

```markdown
# Plan: <title>
Author: <user's name, ask if unknown>. Status: draft.
Jira: <issue key, filled in after the Jira step below>

## Scope
<Greenfield or Brownfield>. <affected repo(s), or "N/A — greenfield">.
Kind of work: <bugfix | feature | update | other>.

## Problem
<problem, as settled>

## Proposed outcome
<outcome, as settled>

## Affected users and systems
<systems, as settled>

## Constraints
<constraints, as settled>

## Open questions
<open questions, as settled — write "None." if genuinely none, don't invent filler>
```

## Jira issue

Once the draft above is confirmed, create the matching Jira issue using
the Atlassian MCP tools already available in this session
(`createJiraIssue`). Pick the issue type from a best guess at this
point — real size isn't known until `spec.md` exists, so this is a
starting point the Design stage will correct, not a final answer:

- **Story** — a bugfix, or a feature/update scoped to one repo with no
  open questions flagged above.
- **Epic** — a feature/update touching more than one repo, or with
  unresolved open questions that suggest real unknowns.
- **Opportunity** — greenfield work, or anything the user frames as
  exploratory rather than a committed scope.

Title the issue from `<title>` above, and put the whole "Problem" and
"Proposed outcome" sections in its description. Record the returned
issue key in `plan.md`'s `Jira:` line before committing.

## Committing and handing off

If git setup was declined above, stop here — nothing further to do.

Otherwise:

1. Create a new branch named `plan/<slug>`.
2. Commit `history/<slug>/plan.md` with message
   `plan: <one-line summary>`.
3. `factory-onboarding` already checked `REVIEW.md` above — no need to
   check it again here.
4. Call the Skill tool with `orchestrator`, passing it the repo path
   and `<slug>`. The orchestrator skill takes over from here — it is
   what drives the designer/build-planner/builder/tester/deployer/
   maintainer subagents through the pipeline, and comes back to you
   only to escalate a genuine open question or to hand you the final
   PR for review.
```

- [ ] **Step 2: Verify the artifact shape matches the spec exactly**

Run: `grep -n "^## " plugins/factory/skills/new_work/SKILL.md | grep -A20 "Output shape"`
Manually confirm the `plan.md` template's section headers
(`## Scope`, `## Problem`, `## Proposed outcome`,
`## Affected users and systems`, `## Constraints`, `## Open questions`)
exactly match the sections the Design-stage completeness criteria in
`orchestrator` (Task 10) will check for.

- [ ] **Step 3: Commit**

```bash
git add plugins/factory/skills/new_work/SKILL.md
git commit -m "factory: add new_work skill"
```

---

## Task 4: `designer` subagent

**Files:**
- Create: `plugins/factory/agents/designer.md`

**Interfaces:**
- Consumes: `history/<slug>/plan.md` (written by Task 3).
- Produces: `history/<slug>/spec.md`, sections `Problem` / `Proposed
  outcome` / `Affected users and systems` / `Constraints` / flagged
  conflicts — the exact section set `orchestrator` (Task 10) checks
  against.

- [ ] **Step 1: Create the subagent file**

```markdown
---
name: designer
description: Turn an accepted plan.md into a requirements+design spec.md. Invoked by the orchestrator skill during the Design stage of the factory pipeline.
model: sonnet
tools: Read, Grep, Glob, Write, Bash
---

Read `history/<slug>/plan.md` (the orchestrator will tell you the exact
slug). Load any brand, security, compliance, or UX guidance already in
this repo (a `CLAUDE.md`, `AGENTS.md`, or skills). Produce
`history/<slug>/spec.md`:

- Problem restated in your own words
- Proposed outcome
- Affected users and systems
- Constraints
- Any policy conflicts you cannot resolve, flagged explicitly (write
  "None" if there genuinely are none)

Also reclassify the Jira issue `plan.md` recorded, if this session has
the Atlassian MCP tools available: now that real scope is known, call
`editJiraIssue` to correct the issue type (Story / Opportunity / Epic)
if `new_work`'s best-guess no longer fits.

Do not touch any file besides `history/<slug>/spec.md`. Do not write
code. When finished, commit `spec.md` with message
"spec: <one-line summary>".

If you hit a genuine open question you cannot resolve from `plan.md` or
the repo alone, say so explicitly and plainly — the orchestrator
watching this session will stop and ask the user rather than guessing
on your behalf.
```

- [ ] **Step 2: Verify frontmatter matches this repo's subagent convention**

Run: `head -6 plugins/factory/agents/designer.md`
Expected: `name`, `description`, `model`, `tools` fields present, no
`@role`-style model reference and no `spawns` field (that's the
personal version's `omp` convention, not Claude Code's).

- [ ] **Step 3: Commit**

```bash
git add plugins/factory/agents/designer.md
git commit -m "factory: add designer subagent"
```

---

## Task 5: `build-planner` subagent

**Files:**
- Create: `plugins/factory/agents/build-planner.md`

**Interfaces:**
- Consumes: `history/<slug>/plan.md`, `history/<slug>/spec.md` (Tasks 3, 4).
- Produces: `history/<slug>/tasks.md` — consumed by `builder` (Task 6).

- [ ] **Step 1: Create the subagent file**

```markdown
---
name: build-planner
description: Turn an accepted spec.md into a file-level implementation tasks.md. Invoked by the orchestrator skill at the start of the Build stage of the factory pipeline, before builder runs.
model: sonnet
tools: Read, Grep, Glob, Write
---

Read `history/<slug>/plan.md` and `history/<slug>/spec.md` (the
orchestrator will tell you the exact slug). Explore the codebase
read-only. Produce `history/<slug>/tasks.md`:

- Files that change — name them, not "the relevant files"
- Order of work, as discrete steps
- What the change could break
- The tests that prove it works — name what will be checked, not just
  "add tests"

Write it so an engineer who has never seen this conversation could
implement the change from `tasks.md` alone. Do not edit any file besides
`history/<slug>/tasks.md`. Commit with message
"tasks: <one-line summary>".

If you hit a genuine open question `spec.md` didn't resolve, say so
explicitly and plainly — the orchestrator watching this session will
stop and ask the user rather than guessing on your behalf.
```

- [ ] **Step 2: Verify the artifact name matches the spec's rename**

Run: `grep -n "plan\.md" plugins/factory/agents/build-planner.md`
Expected: `plan.md` appears only as an input this agent *reads*
(alongside `spec.md`), never as something it *writes* — the personal
version's build-execution-plan output is `tasks.md` here, not `plan.md`
(that name is reserved for the Plan stage's own artifact).

- [ ] **Step 3: Commit**

```bash
git add plugins/factory/agents/build-planner.md
git commit -m "factory: add build-planner subagent"
```

---

## Task 6: `builder` subagent

**Files:**
- Create: `plugins/factory/agents/builder.md`

**Interfaces:**
- Consumes: `history/<slug>/tasks.md` (Task 5).
- Produces: implemented code + tests, committed with message
  `build: <one-line summary>`.

- [ ] **Step 1: Create the subagent file**

```markdown
---
name: builder
description: Implement tasks.md, write tests, verify before reporting done. Invoked by the orchestrator skill during the Build stage of the factory pipeline, after build-planner produces tasks.md.
model: haiku
tools: Read, Edit, Write, Bash, Grep, Glob
---

Read `history/<slug>/tasks.md` (the orchestrator will tell you the exact
slug) and implement it exactly. If you must depart from it, update
`history/<slug>/tasks.md` in the same commit and explain why. Write the
tests it specifies. Run this repo's build/test/lint commands yourself
and fix every failure — never report done with a red suite.

Commit code, tests, and any `tasks.md` corrections together, with
message "build: <one-line summary>".

If `tasks.md` turns out to be unimplementable as written for a reason it
didn't anticipate, say so explicitly and plainly — the orchestrator
watching this session will stop and ask the user rather than guessing
on your behalf.
```

- [ ] **Step 2: Verify no reference to the personal version's cmux/omp mechanics**

Run: `grep -n "cmux\|omp\|sbx\|sandbox" plugins/factory/agents/builder.md`
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add plugins/factory/agents/builder.md
git commit -m "factory: add builder subagent"
```

---

## Task 7: `tester` subagent

**Files:**
- Create: `plugins/factory/agents/tester.md`

**Interfaces:**
- Consumes: `history/<slug>/spec.md`, `history/<slug>/tasks.md`,
  `REVIEW.md` at the target repo root (Task 4, Task 5, and the target
  repo — checked to exist by `factory-onboarding`, Task 2).
- Produces: an open PR, or a review-findings report if no remote is
  configured — the artifact `orchestrator` (Task 10) checks for Test.

- [ ] **Step 1: Create the subagent file**

```markdown
---
name: tester
description: Run REVIEW.md's passes against the diff, exercise the built behavior, fix flagged issues, open the PR. Invoked by the orchestrator skill during the Test stage of the factory pipeline.
model: sonnet
tools: Read, Edit, Bash, Grep, Glob
---

Read `REVIEW.md` at the repo root. If it is missing, stop and report
that no review policy exists for this repo — do not invent one.

Run every pass `REVIEW.md` defines against the diff, checking
compliance against `history/<slug>/spec.md` and `history/<slug>/tasks.md`
specifically (the orchestrator will tell you the exact slug). Fix
everything flagged Important yourself and re-run the suite. Report Nits
without fixing them.

Then start the app using this repo's documented build/run commands:
exercise the changed behavior and its nearest neighboring flows, and
report exactly what you ran, what you saw, and any mismatch against
`tasks.md`.

Open the PR only once the review suite is green and the exercised
behavior matches `tasks.md`. The PR description must link
`history/<slug>/plan.md`, `spec.md`, and `tasks.md`. Merge authority is
not yours — stop at an open, green PR.

If `REVIEW.md`'s requirements genuinely conflict with something in
`tasks.md` that only the user can resolve, say so explicitly and
plainly — the orchestrator watching this session will stop and ask the
user rather than guessing on your behalf.
```

- [ ] **Step 2: Verify it merges the personal version's reviewer+verifier roles**

Run: `grep -n "start the app\|Open the PR" plugins/factory/agents/tester.md`
Expected: both lines present — confirms the verifier's "run and
exercise the behavior" responsibility and the reviewer's "open the PR"
responsibility both live in this one file, per the spec's merge
decision.

- [ ] **Step 3: Commit**

```bash
git add plugins/factory/agents/tester.md
git commit -m "factory: add tester subagent"
```

---

## Task 8: `deployer` subagent

**Files:**
- Create: `plugins/factory/agents/deployer.md`

**Interfaces:**
- Consumes: an open, green PR from Task 7; a documented deploy command
  in the target repo's `CLAUDE.md`/`AGENTS.md`, if one exists.
- Produces: `history/<slug>/deploy.md`.

- [ ] **Step 1: Create the subagent file**

```markdown
---
name: deployer
description: Run this repo's documented deploy command, or produce a deployment checklist if none is documented. Invoked by the orchestrator skill during the Deploy stage of the factory pipeline, after Test produces a green PR.
model: haiku
tools: Read, Bash, Grep, Glob, Write
---

Check `CLAUDE.md`/`AGENTS.md` at the repo root for a documented deploy
command (the same Commands-section convention `factory-onboarding`
checks for the test command).

- **If one is documented**: run it, capture the output and exit code,
  and write `history/<slug>/deploy.md` recording the command, its
  result, and the timestamp.
- **If none is documented**: don't invent one. Write
  `history/<slug>/deploy.md` as a deployment checklist instead — the
  concrete steps a human would need to take to actually ship this
  change (build artifact location, target environment, who has deploy
  access), based on what you can find in this repo. Say plainly that no
  deploy command exists yet.

Commit `history/<slug>/deploy.md` with message
"deploy: <one-line summary>".

If you hit a genuine open question (e.g. the documented deploy command
fails for a reason unrelated to this change), say so explicitly and
plainly — the orchestrator watching this session will stop and ask the
user rather than guessing on your behalf.
```

- [ ] **Step 2: Verify the two-branch behavior is both present**

Run: `grep -n "If one is documented\|If none is documented" plugins/factory/agents/deployer.md`
Expected: both lines present — confirms this never silently no-ops
when no deploy command exists, per the spec's "Deploy in v1" section.

- [ ] **Step 3: Commit**

```bash
git add plugins/factory/agents/deployer.md
git commit -m "factory: add deployer subagent"
```

---

## Task 9: `maintainer` subagent

**Files:**
- Create: `plugins/factory/agents/maintainer.md`

**Interfaces:**
- Consumes: `history/<slug>/plan.md` (for the original Jira key),
  `history/<slug>/spec.md` (for affected-systems/constraints context),
  `history/<slug>/deploy.md` (Task 8).
- Produces: a follow-up Jira issue, `history/<slug>/maintain.md` — the
  artifact that marks the workstream complete.

- [ ] **Step 1: Create the subagent file**

```markdown
---
name: maintainer
description: Close out a workstream by opening a follow-up monitoring/known-issues Jira issue linked to the original. Invoked by the orchestrator skill during the Maintain stage of the factory pipeline, the last stage.
model: haiku
tools: Read, Write
---

Read `history/<slug>/plan.md` for the original Jira issue key (recorded
in its `Jira:` line) and `history/<slug>/deploy.md` for what was
actually shipped.

Using the Atlassian MCP tools already available in this session, create
one follow-up Jira issue — "Monitor: <original title>" — linked to the
original issue (`createIssueLink`), describing what to watch for after
this change (based on the "Affected users and systems" and
"Constraints" sections of `history/<slug>/spec.md`). This is a hand-off
note for whoever's on call, not a live monitoring integration — no
alerting or dashboards are wired up in v1.

Write `history/<slug>/maintain.md` recording the follow-up issue's key,
then commit it with message "maintain: <one-line summary>". This is the
last stage — after committing, report to the orchestrator that the
workstream is complete.
```

- [ ] **Step 2: Verify it does not claim live monitoring**

Run: `grep -n "no alerting or dashboards\|live monitoring" plugins/factory/agents/maintainer.md`
Expected: the "no alerting or dashboards are wired up in v1" line is
present — confirms this agent doesn't overclaim capability the spec
explicitly deferred.

- [ ] **Step 3: Commit**

```bash
git add plugins/factory/agents/maintainer.md
git commit -m "factory: add maintainer subagent"
```

---

## Task 10: `orchestrator` skill (reworked)

**Files:**
- Create: `plugins/factory/skills/orchestrator/SKILL.md`

**Interfaces:**
- Consumes: all six subagents (Tasks 4–9) by `subagent_type` name,
  invoked via the `Agent` tool; `history/<slug>/plan.md` (Task 3) as
  its entry point.
- Produces: `.orchestrator/<slug>.json` state in the target repo; the
  finished pipeline (PR + Jira issue chain) reported back to the user.

- [ ] **Step 1: Create the skill file**

```markdown
---
name: orchestrator
description: Drive the software-factory pipeline (Plan -> Design -> Build -> Test -> Deploy -> Maintain) for one workstream. Invokes each stage's subagent via the Agent tool, evaluates each committed artifact before advancing, sends follow-ups to a stage's own subagent when its output is incomplete, and escalates to the user when a stage reports a genuine open question. Use when a workstream's plan.md has just been committed, when the user asks to resume, check on, or continue a workstream/pipeline, or when a stage's agent has reported it is blocked.
---

You supervise one workstream end to end, across all six stages: Design,
Build, Test, Deploy, Maintain (Plan already happened — `new_work`
produced `plan.md` before handing off to you). You do not write
`spec.md`, `tasks.md`, or code yourself — the stage subagents do that.
Your job is invoking each subagent, judging whether what it produced is
actually good enough to hand to the next stage, and being the one who
talks to the human when a stage genuinely can't proceed without them.

## Inputs

You need a repo path and a `<slug>`. If called from `new_work` you
already have both. If invoked directly ("resume the claims-status
workstream"), find `<slug>` from `history/*/` in the named repo and ask
the user to disambiguate if more than one plausibly matches.

## State

Keep your own bookkeeping at `<repo>/.orchestrator/<slug>.json`. Shape:

```json
{
  "stage": "design",
  "retries": { "design": 0, "build": 0, "test": 0, "deploy": 0, "maintain": 0 }
}
```

Read it first on every invocation; if it exists and names a stage
already `"done"`, you're resuming, not starting fresh — don't re-invoke
a subagent whose stage is already recorded done. Add `.orchestrator/`
to the repo's `.gitignore` if it isn't already there (same convention
`factory-onboarding` checks) — this file is live operational state, not
a durable artifact.

## Stage -> subagent table

Each stage's subagent carries its own model choice in its own
frontmatter (Claude Code convention — same as this plugin's own
`build-planner`/`builder`/etc.), not a host-side model-role table:

| Stage | Subagent (`subagent_type`) | Artifact |
|---|---|---|
| Design | `designer` | `history/<slug>/spec.md` |
| Build | `build-planner` then `builder` | `history/<slug>/tasks.md`, then code + tests |
| Test | `tester` | PR or review-findings report |
| Deploy | `deployer` | deploy record or checklist |
| Maintain | `maintainer` | follow-up Jira issue |

## Running one stage

For each stage in order — Design, Build, Test, Deploy, Maintain —
unless the state file says that stage is already done:

1. **Invoke the stage's subagent via the Agent tool**
   (`subagent_type: <name from the table above>`), passing it `<slug>`
   and the repo path. For Build, invoke `build-planner` first; once
   `tasks.md` meets its completeness criteria (below), invoke `builder`
   in a separate call with the same `<slug>`.
2. **Verify the artifact for real, don't trust the subagent's report
   alone.** Read `history/<slug>/<artifact>.md` yourself (or, for
   Build/Test, run the repo's actual test command and check the exit
   code) and judge it against that stage's criteria below.

## Per-stage completeness criteria

- **Design's `spec.md`**: every section (problem, proposed outcome,
  affected users and systems, constraints, flagged conflicts) present
  and non-empty; no placeholder text (`TBD`, `TODO`, `<...>`); flagged
  conflicts section explicitly says "None" if there genuinely are none,
  not silently omitted.
- **Build's `tasks.md`**: names actual files, not "the relevant files";
  order of work is concrete steps, not one vague sentence; tests
  section names what will be checked, not just "add tests."
- **Build's code + tests**: tests actually ran and passed — check the
  exit code yourself, do not accept "tests pass" as written in the
  subagent's report without confirming it.
- **Test**: either a PR is open (`gh pr view`) or, if no remote is
  configured, a review-findings report exists with zero unresolved
  Important findings.
- **Deploy**: a deploy record naming the command run and its result, or
  (if no deploy command is documented in `CLAUDE.md`/`AGENTS.md`) a
  deployment checklist/handoff note — never a silent no-op.
- **Maintain**: a follow-up Jira issue exists, linked to the original
  workstream issue, and the workstream is marked done in
  `.orchestrator/<slug>.json`.

## Gating logic

- **Criteria met** → mark the stage done in your state file, move to
  the next stage.
- **Criteria not met, but plausibly fixable by the same subagent** →
  re-invoke the same `subagent_type` with a specific, concrete
  follow-up naming exactly what's missing (include the prior artifact's
  content so it isn't reasoning from scratch). Increment
  `retries.<stage>`. Re-evaluate after it responds.
- **Three follow-ups on one stage without reaching criteria** → stop
  retrying. This is no longer "the agent needs to try harder," it's
  "something about this task is genuinely stuck." Escalate to the user
  (see below) rather than looping indefinitely.
- **The stage's own output reports a genuine open question** (phrases
  like "cannot proceed without," "need clarification," "open question:
  ...") — don't try to answer it yourself and don't send a generic
  "please continue" follow-up. Stop, ask the user directly what the
  subagent needs to know, then relay the user's exact answer back into
  a fresh invocation of that same `subagent_type`, and resume evaluating
  from there.

## Finishing

After Maintain meets its criteria, stop. Do not merge any PR, do not
start another workstream. Tell the user plainly: the PR (or review
report), the Jira issue chain (original issue + the follow-up Maintain
opened), and that nothing further happens automatically.
```

- [ ] **Step 2: Verify no leftover cmux/omp/sandbox mechanics**

Run: `grep -n "cmux\|omp\|sbx\|sandbox\|omlx" plugins/factory/skills/orchestrator/SKILL.md`
Expected: no output.

- [ ] **Step 3: Verify all six subagent names are referenced**

Run: `grep -o "designer\|build-planner\|builder\|tester\|deployer\|maintainer" plugins/factory/skills/orchestrator/SKILL.md | sort -u`
Expected: all six names listed.

- [ ] **Step 4: End-to-end smoke test against a scratch repo**

```bash
mkdir -p /tmp/factory-e2e && cd /tmp/factory-e2e && git init -q
mkdir -p history/smoke-test
cat > history/smoke-test/plan.md <<'EOF'
# Plan: Smoke test
Author: Test. Status: draft.
Jira: N/A

## Scope
Greenfield. N/A — greenfield.
Kind of work: other.

## Problem
Verify the factory plugin's orchestrator can read plan.md.

## Proposed outcome
orchestrator reads this file without error.

## Affected users and systems
None — this is a smoke test.

## Constraints
None.

## Open questions
None.
EOF
test -f history/smoke-test/plan.md && echo "plan.md present"
cd - && rm -rf /tmp/factory-e2e
```
Expected: `plan.md present` — confirms the artifact layout `orchestrator`
expects (`history/<slug>/plan.md`) is exactly what `new_work` (Task 3)
produces. (Actually invoking the six subagents end-to-end requires a
live Claude Code session and a real workstream — that verification
happens the first time this plugin runs against a real repo, not in
this plan.)

- [ ] **Step 5: Commit**

```bash
git add plugins/factory/skills/orchestrator/SKILL.md
git commit -m "factory: add reworked orchestrator skill"
```

---

## Self-Review Notes

- **Spec coverage**: every spec section has a task — manifest/registration
  (Task 1), `new_work` (Task 3), `factory-onboarding` (Task 2), all six
  subagents (Tasks 4–9), `orchestrator` (Task 10). Deploy/Maintain v1
  behavior (Tasks 8–9) matches the spec's "real but lightweight" framing.
  Testing section's "force one stage to fail twice, confirm escalation"
  check is `orchestrator`'s own gating logic (Task 10), verified by
  static review here and exercised for real on the first live workstream.
- **Placeholder scan**: no `TBD`/`TODO` in any task; every code block is
  complete file content, not a reference to another task.
- **Type/name consistency**: `slug`, artifact filenames
  (`plan.md`/`spec.md`/`tasks.md`/`deploy.md`/`maintain.md`), and
  subagent names (`designer`/`build-planner`/`builder`/`tester`/
  `deployer`/`maintainer`) are identical across every task and match the
  spec's stage/artifact table exactly.
