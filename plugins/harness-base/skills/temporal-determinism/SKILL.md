---
name: temporal-determinism
description: Tripwires for non-deterministic APIs in Temporal workflow code (Python, TypeScript, Go, Java, .NET, Ruby). Use when writing or reviewing code inside a Temporal workflow function/class (files importing a Temporal SDK, decorated with @workflow.defn / [Workflow], or under a workflows/ directory) — catches replay-breaking bugs generic model knowledge won't flag.
---

# Temporal determinism

Workflow code must produce identical results on every replay. Anything that
can return a different value the second time it runs is a correctness bug
that surfaces in production as a non-deterministic-history error, often
weeks after the code shipped — not a style nit.

This skill is a checklist, not a tutorial. If deeper Temporal design help is
needed (activities, signals, versioning strategy), use the
`temporal:temporal-developer` skill instead — this one only exists to catch
the tripwires below during writing/review.

## The rule

**Is this call inside workflow code (not an Activity)? Then it must be
deterministic, or routed through an SDK-provided safe wrapper.**

## Tripwires — forbidden in workflow code, with the fix

| Non-deterministic thing | Why it breaks replay | Fix |
|---|---|---|
| Wall-clock time: `time.Now()`, `Date.now()`, `DateTime.Now`, `time.time()` | Returns a different value on replay | `workflow.Now()` / SDK-equivalent workflow clock |
| Random values: `math/rand`, `Math.random()`, `random` module, ad-hoc UUID gen | Different value each execution | `workflow.SideEffect()` (Go/Java/.NET) or the SDK's workflow-safe random/UUID helper |
| Direct network, DB, file, or disk I/O | External state changes between calls | Move to an Activity; workflow only orchestrates |
| Native threads/goroutines, raw async I/O outside SDK constructs | Scheduling order isn't replay-safe | Use the SDK's workflow-safe concurrency primitives (e.g. `workflow.Go` in Go, not a bare goroutine) |
| Iterating an unordered map/dict/set where iteration order affects logic | Go map order is randomized per-process | Sort keys first, or use an ordered structure |
| Branching on external mutable state (env var, feature flag, config file read directly) | Value can differ between original run and replay | `workflow.GetVersion()` / `Patched()` for versioned branching |
| Global/package-level mutable state shared across workflow executions | Leaks state between independent runs | Keep all workflow state inside the workflow instance |
| Any activity call not awaited/idempotent-aware in a way that assumes it always succeeds first try | Retries change apparent history | Design for at-least-once activity execution explicitly |

## What's fine

- Everything above is fine **inside an Activity** — activities are expected
  to do I/O, call `time.Now()`, hit the network. The workflow just must not
  do those things directly.
- SDK-provided deterministic helpers (`workflow.Now()`, `workflow.Sleep()`,
  `workflow.SideEffect()`, `workflow.GetVersion()`, local activities for
  lightweight non-deterministic work) exist precisely to make the common
  cases safe — reach for those instead of removing the capability.

## Review checklist

When writing or reviewing workflow code, grep for: `time.Now`, `Date.now`,
`rand`, `random`, `uuid` (unqualified), direct HTTP/DB client calls, raw
`go func`/`Thread`/`async` usage, and any `os.Getenv`/config read — inside a
workflow file, each one is a flag to check against the table above before
it ships.
