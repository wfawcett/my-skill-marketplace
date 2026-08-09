# Harness taxonomy (reference)

Reconciles three ad-hoc breakdowns of "what a coding harness is made of" that
came up in conversation — Addy Osmani's list, Parvez Mohammed's subsystem
table, and an informal instructions/tools/permissions/guardrails/lifecycle
split — into one standardized set of layers. Use this as the shared
vocabulary going forward instead of re-deriving it per conversation.

This is a naming/grouping exercise, not new design. It doesn't replace the
"seven things a real harness has to own" in `README.md` — the seven pillars
are the *why*, this taxonomy is the *what it's made of*. See the mapping at
the end of this file for how they line up.

## The eight layers

1. **Instructions** — what to do, how to think.
   *Artifacts:* CLAUDE.md, AGENTS.md, system prompts, skill files, subagent
   prompts.
2. **Tools & integrations** — what the agent can do.
   *Artifacts:* Skills, MCP servers, tool descriptions, LSP servers.
3. **Permissions & guardrails** — what's allowed or forbidden.
   *Artifacts:* `settings.json` allow/deny lists, PreToolUse policy checks.
4. **Execution environment** — where code runs.
   *Artifacts:* sandbox, filesystem layout, git config, containers.
5. **State & memory** — what persists across sessions.
   *Artifacts:* progress files, task lists, git history.
6. **Control & orchestration** — staging, handoff, routing, lifecycle.
   *Artifacts:* hooks (PreToolUse/PostToolUse/Stop), subagent spawning,
   model routing policy, Spec-Kit/Superpowers workflow stages.
7. **Verification & evaluation** — proof before victory.
   *Artifacts:* tests, lint, typecheck, mutation testing.
8. **Observability & audit** — proof of what happened.
   *Artifacts:* logs, traces, cost/token metering, approval records.

## Open seam, not yet decided

Layers 3 (permissions & guardrails) and 6 (control & orchestration) overlap:
a Stop hook that blocks "done" on failing tests is simultaneously a
guardrail (what's forbidden — claiming done on red) and orchestration (when
to hand control back). Decide per-artifact which layer owns it rather than
letting it float — this taxonomy doesn't resolve that on its own.

## Traceability: source breakdowns → layers

| Layer | Osmani | Mohammed | Informal |
|---|---|---|---|
| 1. Instructions | system prompts, CLAUDE.md, AGENTS.md, skill files, subagent prompts | Instructions | Instructions |
| 2. Tools & integrations | tools, skills, MCP servers | — | Tools |
| 3. Permissions & guardrails | (part of "bundled infrastructure") | — | Permissions, Guardrails |
| 4. Execution environment | bundled infrastructure (filesystem, sandbox, browser) | — | — |
| 5. State & memory | (implicit in orchestration) | State | — |
| 6. Control & orchestration | orchestration logic, hooks/middleware | Scope, Lifecycle | Lifecycle, Subagents |
| 7. Verification & evaluation | (implicit in orchestration) | Verification | — |
| 8. Observability & audit | observability (logs, traces, cost/latency) | — | — |

## Mapping to this project's seven pillars (`README.md`)

| Pillar | Taxonomy layer(s) |
|---|---|
| Context grounding | 1 (Instructions) |
| Staged generation | 6 (Control & orchestration) |
| Verification loops | 7 (Verification & evaluation) |
| Guardrails and policy | 3 (Permissions & guardrails) |
| Adversarial review | 6 (subagent framing) + 7 (what it checks) |
| Traceability/audit | 8 (Observability & audit) |
| Human gate | 6 (Control & orchestration — approval points) |

## Provenance note

This taxonomy was drafted by a Haiku research subagent tasked with
reconciling the three source breakdowns and citing supporting material. The
grouping/reconciliation above was reviewed and is usable as-is. Its cited
external sources (blog posts, arXiv papers) were **not** independently
verified and several look fabricated on inspection — they're omitted here.
Anthropic's own documented build order (CLAUDE.md → Hooks → Skills → Plugins
→ MCP servers) is already sourced separately in
`08-research-notes-and-sources.md` and is the only external claim reused
above.
