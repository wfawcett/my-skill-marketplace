# Governance

## The DRI model

DRI = Directly Responsible Individual (popularized by Apple, widely
adopted since) — one specific named person owns a decision or piece of
infrastructure, not a committee or "the team," so there's no ambiguity about
who to go to when something breaks or needs a call made.

Anthropic's own guidance for large-scale Claude Code rollouts names this
pattern directly: successful rollouts required dedicated infrastructure
investment *before* broad access, with a DRI controlling conventions,
settings, the marketplace, and permissions. They also name an emerging role
— "agent manager," a hybrid PM/engineer function managing the Claude Code
ecosystem.

**William Fawcett is the DRI for the CHG harness** — owns `chg-base`, the
hooks, the conventions, and the go/no-go on what graduates from pilot to
org-wide.

## Committee structure

Monthly meeting with lead devs to evolve the harness (standards content,
`chg-base` plugin contents, pilot go/no-go decisions).

**Worth adding:** a security/compliance seat, not just engineering leads.
Anthropic's guidance for regulated industries specifically recommends
defining approved skills/plugins upfront and enforcing code-review parity
(AI-generated code follows the same review as human code) — a
cross-functional working group (engineering, security, governance) is their
recommended structure, not an engineering-only one. Given CHG is healthcare,
this isn't optional polish.

## Two separate review cadences — don't conflate them

1. **Standards *content* review — monthly.** Is the standard itself still
   current? This is what the lead-dev committee is already set up to do.
2. **Rule/config *health* review — roughly quarterly (every 3–6 months,
   especially after major model releases).** Are existing CLAUDE.md rules
   and hooks still earning their keep, or have they become obsolete/
   counterproductive as the underlying model improves? Anthropic's example:
   a rule forcing single-file-at-a-time refactors was a workaround for an
   older model's coordination limits, and it actively constrains a newer
   model capable of coordinated multi-file changes. This is a different
   question than "is the standard current" and needs its own slot on the
   calendar, not an assumption that the monthly meeting covers it.

## What "done" looks like for a harness change

Not formally defined yet — see `99-open-questions.md`. At minimum, changes
to `chg-base` or shared hooks should go through the same review the
committee applies to any shared infrastructure, with the DRI as final
approver.
