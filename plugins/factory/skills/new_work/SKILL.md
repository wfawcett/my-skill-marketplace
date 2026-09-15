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
