# precompact-handoff

Structured compaction handoff for Claude Code, via hooks.

## Mechanism

- **`compaction.md`** (project root, alongside `CLAUDE.md`): the user-authored customization
  point. Its full contents are used verbatim as the prompt/instructions passed to a child
  `claude -p` call — edit this file to change how compaction summarizes, no script changes
  needed. If it's missing, the hook falls back to the built-in default prompt (see
  `compaction.md.example` for a starting point — copy it to your project root as
  `compaction.md` to customize).
- **PreCompact** (`hooks/scripts/precompact-handoff.sh`, matcher `manual|auto`): reads
  `transcript_path` from stdin JSON, reads `compaction.md` for the prompt (or the fallback
  default), pipes the transcript through a child `claude -p` call using that prompt, writes
  the result to `.claude/handoff/latest.md` in the project.
  - Recursion guard: sets `PRECOMPACT_HANDOFF_CHILD=1` on the child `claude -p` call; the hook
    exits immediately if that var is already set, so the child can't retrigger this same hook.
- **SessionStart** (`hooks/scripts/sessionstart-handoff.sh`, matcher `compact`): reads
  `.claude/handoff/latest.md` from the project and returns it as
  `hookSpecificOutput.additionalContext`, so the post-compaction session gets the structured
  handoff instead of relying only on Claude Code's built-in generic summary.

Handoff state (`.claude/handoff/`) lives in the consuming project, not in this plugin, so each
project keeps its own history and logs.

## Logs

`.claude/handoff/logs/last-precompact-input.json` and `last-precompact-stderr.log` in the
project — last PreCompact hook input/errors, for debugging.
