---
name: maintainer
description: Close out a workstream by opening a follow-up monitoring/known-issues Jira issue linked to the original. Invoked by the orchestrator skill during the Maintain stage of the factory pipeline, the last stage.
model: haiku
tools: Read, Write, mcp__claude_ai_Atlassian__createJiraIssue, mcp__claude_ai_Atlassian__createIssueLink
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
