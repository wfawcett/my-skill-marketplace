# Internal plugin marketplace and `chg-base`

## The plan

Stand up a Claude Code marketplace to host CHG's own plugins (hooks,
subagents, skills, etc.). A `chg-base` plugin carries the company's
universal pieces — e.g. a security-audit skill, subagents that default to
Haiku. Update the plugin in one place, propagate it to every team. Teams opt
in by adding `extraKnownMarketplaces` and `enabledPlugins` to their repo's
`.claude/settings.json`.

Deliberately **sparse at first**, evolved via a monthly meeting with lead
devs.

## What Claude Code's plugin system actually supports

A plugin is a self-contained directory that can bundle: skills, agents
(subagents), hooks, MCP servers, LSP servers, and monitors, described by an
optional `.claude-plugin/plugin.json` manifest. Relevant details for
designing `chg-base`:

- **Skills** live in `skills/<name>/SKILL.md`, auto-discovered on install.
- **Agents** (subagents) live in `agents/*.md` with frontmatter (`name`,
  `description`, `model`, `effort`, `maxTurns`, `tools`,
  `disallowedTools`). For security reasons, plugin-shipped agents can't
  declare their own `hooks`, `mcpServers`, or `permissionMode` — those stay
  at the plugin or user level.
- **Hooks** live in `hooks/hooks.json`, same event set as user-defined
  hooks (`PreToolUse`, `PostToolUse`, `Stop`, `SubagentStop`, etc.).
- **LSP servers** — see `04-lsp-and-code-navigation.md`. Note the
  first-registered-wins collision behavior when two plugins claim the same
  file extension — a real reason *not* to duplicate LSP config that the
  official marketplace already provides.
- **A `CLAUDE.md` at a plugin's root is NOT loaded as project context.**
  Plugins contribute context through skills/agents/hooks only. Anything
  meant to load into Claude's context must be a skill.
- **Installation scopes**: `user`, `project` (checked into the repo, shared
  via version control — this is the one teams will use), `local`, and
  `managed` (org-controlled policy, read-only).
- Version pinning: setting `version` in `plugin.json` pins a team to that
  version until they bump it; omitting it tracks whatever the marketplace
  entry serves. **Worth confirming explicitly how CHG wants teams to pin
  vs. float** before wide rollout — "update once, propagates everywhere" is
  only automatically true if teams are on a floating version, and that has
  its own staleness/drift risk if nobody's watching what changed.

## Recommended build order (per Anthropic's own guidance)

**CLAUDE.md → Hooks → Skills → Plugins → MCP servers**, with LSP
integrations and subagents as later/advanced additions. Get the foundations
solid in individual repos before over-investing in the distribution
mechanism — `chg-base` should stay genuinely sparse rather than becoming the
place foundational work gets deferred to.

## `chg-base` v1 contents

See `07-v1-harness-plan.md` for the full scoped list. Summary:

- `temporal-determinism` skill (see `04-lsp-and-code-navigation.md` for why
  this is prioritized — it's a correctness hazard, not a style rule).
- `security-review` skill (the standing example from the original ask).
- Two subagent definitions: `haiku-coder`, `sonnet-coder` (see
  `03-model-routing.md`).

Deliberately excluded from v1: Graphify config, mutation testing, coverage-
diff enforcement. These wait for pilot signal.

## Governance loop

Monthly lead-dev meeting evolves `chg-base` content. See `06-governance.md`
for the recommended cadence structure and who else might need a seat at that
table.
