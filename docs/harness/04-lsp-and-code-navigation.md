# Code navigation: LSP, and where a knowledge graph (Graphify) fits

## Anthropic's own philosophy: agentic search, not an index

Anthropic's guidance for Claude Code in large codebases is explicitly
anti-RAG/anti-index: Claude navigates like an engineer, traversing the file
system and grepping, operating locally without a centralized index. The
argument is that a pre-built index/embedding pipeline goes stale the moment
code changes, while agentic search always reads current state. The tradeoff
is that navigation quality depends heavily on how well the codebase is set
up (CLAUDE.md hygiene, hierarchy, per-directory scoping).

For symbol-level precision beyond grep, their recommendation is **LSP
integration**, not an index — go-to-definition, find-references, type info,
sourced live from the actual language server.

## LSP is a first-class, officially supported plugin component

Not something to build from scratch. Claude Code's plugin system treats LSP
servers as a named component type alongside skills/agents/hooks/MCP.
Capabilities:

- **Instant diagnostics** — errors/warnings surfaced immediately after each
  edit.
- **Code navigation** — go to definition, find references, hover info.
- **Language awareness** — type info and docs for symbols.

Pre-built official plugins exist already, installable via `/plugin` →
Discover → search "lsp":

| Plugin | Language server | Covers |
|---|---|---|
| `pyright-lsp` | Pyright | Python |
| `typescript-lsp` | TypeScript Language Server | `.ts`, `.tsx`, `.js`, `.jsx`, `.mts`, `.cts`, `.mjs`, `.cjs` |
| `rust-analyzer-lsp` | rust-analyzer | Rust |

Community coverage extends to Go, Java, C/C++, C#, PHP, Kotlin, Ruby,
PowerShell, HTML/CSS.

### Mapped to our actual stack

- **Vanilla JavaScript (Fastify + awilix)** → covered by `typescript-lsp`
  (it explicitly handles `.js`/`.mjs`/`.cjs`, not just TypeScript).
- **TypeScript (Temporal)** → covered by `typescript-lsp`.
- **Python (FastAPI/MCP)** → covered by `pyright-lsp`.

**All three of our languages are already covered by official plugins. No
custom `.lsp.json` needed at the language level.** Action item is just:
install `pyright-lsp` and `typescript-lsp` org-wide.

### Operational catches to plan around

1. **The plugin only wires up the connection — the language server binary
   itself must be installed separately** (e.g. `pip install pyright`) on
   every dev machine and CI image. This is DRI-owned infrastructure work,
   not a one-click install.
2. **Only one LSP server can claim a given file extension, first-registered
   wins, silently.** If `chg-base` ever ships its own `.lsp.json` for a
   language the official marketplace already covers, and a team also
   installs the official plugin, whichever loads first wins with no error
   shown. Decision: **don't bundle LSP config in `chg-base` for anything the
   official marketplace already serves.** Only write custom `.lsp.json` for
   genuinely uncovered languages/tools.

## What LSP does *not* solve: framework-specific correctness

LSP understands the language, not our patterns layered on top of it. It has
no concept of:

- **awilix** — it can tell you a function's type signature; it can't catch a
  DI registration that violates our container-setup convention (e.g. wrong
  lifetime scope).
- **Temporal** — this is a real correctness hazard, not just a style
  preference. Workflow code has hard determinism constraints (no direct
  `Date.now()`, no non-deterministic branching, activities vs. workflows are
  different execution contexts). A model with generic TypeScript knowledge
  will happily write `Date.now()` inside a workflow function — it looks
  fine, passes review at a glance, and breaks on replay in production. This
  is a strong candidate for an early skill and/or a guardrail hook (a
  regex/AST check flagging known-nondeterministic APIs inside files under a
  workflows path).
- **FastAPI/MCP server conventions** — how we structure MCP tool handlers,
  auth patterns for internal servers.

These are CLAUDE.md/skills/hooks problems, not LSP or graph-tool problems.

## Graphify: useful, but for a narrower job than general navigation

`Graphify-Labs/graphify` converts a codebase (plus docs, SQL schemas,
configs) into a queryable knowledge graph using local tree-sitter AST
parsing (no LLM calls, nothing leaves the machine, 40+ languages). Outputs
`graph.json` (traversable, not vector embeddings), `GRAPH_REPORT.md` (god
nodes, community detection via Leiden clustering), `graph.html`
(visualization). Integrates via a `PreToolUse` hook that nudges (or in
`--strict` mode, blocks) raw file reads in favor of graph queries.

**Tension worth being explicit about:** this is exactly the kind of static
index Anthropic's own guidance argues against for in-repo navigation — a
snapshot that goes stale until someone regenerates it, which is a new
maintenance obligation (a hook or CI job to rebuild it, someone who owns
that), not a free win. For single-repo navigation, LSP + hierarchical
CLAUDE.md is probably lower-maintenance and already "current" by
construction.

**Where it earns its cost: the cross-repo / microservice-interaction
problem** — our backburnered "dynamic context" item. Pure agentic grep
fundamentally can't see across repo boundaries: no textual link from a call
in Repo A to its handler in Repo B unless both are checked out in the same
workspace. LSP doesn't solve this either (a language server's project scope
doesn't span independently-deployed services). Graphify's **global graph**
feature (`graphify global add <repo-graph> --as <name>`) registers multiple
repos' graphs together and supports cross-repo queries ("what connects auth
to database," path-tracing between named symbols across services) — a
capability nothing else here provides.

### Recommendation

Don't adopt Graphify broadly as an in-repo navigation layer. Pilot it
narrowly for the cross-repo interaction question specifically, once that
problem is actually being tackled (see `07-v1-harness-plan.md` — currently
deferred). If adopted, someone needs to own the regeneration cadence for
`graphify-out/graph.json` — it's a new artifact with a shelf life.
