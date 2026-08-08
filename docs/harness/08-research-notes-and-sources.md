# Research notes and sources

External research pulled into the design conversation, with links. Fetches
against several domains (claude.com, arxiv.org, dev.to, thepromptshelf.dev,
techery.ai, oakheartlab.com, augmentcode.com, jsmanifest.com,
engineering.fb.com, timchao.site, deepwiki.com, amazingcto.com) were blocked
by the network egress proxy in the research session — the summaries below
come from search-result snippets and the sources that *did* load
(github.com, code.claude.com), not full-page fetches in every case. Re-verify
anything load-bearing before treating it as ground truth.

## Test gaming / TDD enforcement

- [DevAssure — Your AI Coding Agent Might Be Gaming Its Own Tests](https://www.devassure.io/blog/ai-coding-agents-gaming-their-own-tests/) —
  the RepoRescue study numbers (37–52% full-patch pass rate vs. 20–24% when
  test edits are excluded from the audit).
- [tdd-guard (GitHub)](https://github.com/nizos/tdd-guard) and
  [Probity (GitHub)](https://github.com/nizos/probity) — the TDD-enforcement
  hook tool and its successor. Confirmed via direct fetch: hooks into every
  file write/shell command, reads session transcript directly (not test-
  reporter dependent), `enforceTdd()` rule blocks "adding production code
  before a failing test has been observed." Tamper-lock behavior (editing an
  existing test to force a pass) not confirmed from available docs — verify
  in pilot.
- [TDAD: Test-Driven Agentic Development (arXiv 2603.17973v2)](https://arxiv.org/abs/2603.17973v2) —
  graph-based impact analysis; the "TDD instructions without infrastructure
  made regressions worse" finding (9.94% vs. 6.08% baseline); reduced
  regressions 70% (6.08% → 1.82%) with targeted test-impact context.
- Test-Driven *AI Agent* Definition (a differently-scoped, similarly-named
  paper) — the hidden-tests-in-a-separate-Docker-volume-never-mounted
  isolation architecture; visible test directories made read-only before
  execution.
- [Meta Engineering — LLMs are the Key to Mutation Testing and Better Compliance](https://engineering.fb.com/2025/09/30/security/llms-are-the-key-to-mutation-testing-and-better-compliance/) —
  Automated Compliance Hardening (ACH), LLM-driven mutation testing at scale.

## Spec-driven development / workflow frameworks

- [Spec Kit vs. Superpowers — comparison and combining guide (DEV Community)](https://dev.to/truongpx396/spec-kit-vs-superpowers-a-comprehensive-comparison-practical-guide-to-combining-both-52jj)
- [superspec — Superpowers Bridge for Spec-Kit (GitHub)](https://github.com/WangX0111/superspec) —
  confirmed via direct fetch: commands, directory structure, execution
  markers, human checkpoints, as documented in `01-workflow-standardization.md`.
- [Spec-Kit discussion #1889](https://github.com/github/spec-kit/discussions/1889) —
  live community discussion on the exact Spec-Kit/Superpowers integration
  question.

## Claude Code harness architecture (Anthropic's own guidance)

- ["How Claude Code works in large codebases: Best practices and where to start" (Claude blog)](https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start) —
  fetched via a GitHub mirror
  ([RobGruhl/anthropic-docs-mirror](https://github.com/RobGruhl/anthropic-docs-mirror/blob/main/claude-blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start.md))
  since the primary domain was blocked in-session. Source of: the five
  extension points and build order, the DRI/agent-manager framing, the
  3–6-month rule-health review cadence, the microservices guidance
  (per-subdirectory CLAUDE.md + LSP, not an index), the anti-RAG/anti-index
  philosophy.
- [Claude Code plugins reference (code.claude.com)](https://code.claude.com/docs/en/plugins-reference) —
  confirmed via direct fetch: full plugin component schema (skills, agents,
  hooks, MCP servers, LSP servers, monitors, themes), `.lsp.json` format,
  installation scopes, version pinning behavior, the "first-registered LSP
  server wins the extension, silently" collision rule.
- [Claude Code on the web — get started](https://code.claude.com/docs/en/web-quickstart) and
  [Claude Code on the web — full reference](https://code.claude.com/docs/en/claude-code-on-the-web) —
  confirmed via direct fetch: the diff-view is the primary file-viewing
  surface (file list left, changes right, inline comments); no separate
  general file-tree browser is documented; `--teleport` to pull a cloud
  session into a local terminal for full file-browsing.

## LSP integration

- [Claude Code plugins reference — LSP servers section](https://code.claude.com/docs/en/plugins-reference#lsp-servers) —
  official plugins: `pyright-lsp`, `typescript-lsp`, `rust-analyzer-lsp`;
  `.lsp.json` schema (`command`, `extensionToLanguage`, `args`, `transport`,
  `diagnostics`, etc.); binary must be installed separately from the plugin.
- Search-result-sourced (not directly fetched):
  [TypeScript LSP – Claude Plugin](https://claude.com/plugins/typescript-lsp),
  confirming `typescript-lsp` covers `.ts`, `.tsx`, `.js`, `.jsx`, `.mts`,
  `.cts`, `.mjs`, `.cjs`.

## Code indexing / knowledge graphs

- [Graphify (GitHub)](https://github.com/Graphify-Labs/graphify) — confirmed
  via direct fetch: tree-sitter AST parsing (40+ languages, no LLM calls),
  `graph.json`/`GRAPH_REPORT.md`/`graph.html` outputs, confidence tagging
  (EXTRACTED vs. INFERRED), Leiden community detection, `PreToolUse` hook
  integration (nudge or `--strict` block), global cross-repo graph feature
  (`graphify global add ... --as <name>`).

## Model routing / cost

- Search-result-sourced: Haiku ~15x cheaper per token than Opus;
  `CLAUDE_CODE_SUBAGENT_MODEL` env var forces a single model for every
  subagent in a session (highest-precedence override, useful as a cost
  ceiling / compliance switch).
- General agent fault-tolerance pattern (not use-case-specific to coding
  cost control — this application is original to this conversation):
  [Mindra — Fault-Tolerant AI Agents](https://mindra.co/blog/fault-tolerant-ai-agents-failure-handling-retry-fallback-patterns) —
  tiered escalation (cheap model → retry with feedback → bigger model →
  human fallback).
