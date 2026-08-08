---
name: security-review
description: Baseline security checklist for reviewing a diff or PR before merge — secrets, injection, authn/authz, and PHI/PII handling. Use when asked to security-review, security-check, or audit pending changes for security issues, especially in services touching patient/member data.
---

# Security review (harness baseline)

A fast, deterministic pass over a diff — not a full pentest. Flag findings
with file:line, severity (block/warn), and the concrete fix. If nothing
below applies, say so plainly rather than padding the review with
generic advice.

## Scope

Review the diff against the target branch (or the changes described), not
the whole repo. Read enough surrounding context to judge intent, but don't
re-review unrelated code the diff doesn't touch.

## Checklist

1. **Secrets and credentials** — API keys, tokens, connection strings,
   passwords committed in source, config, or test fixtures. Includes
   secrets pasted into log statements.
2. **Injection** — unparameterized SQL/NoSQL queries built via string
   concatenation, shell commands built from unsanitized input, unsafe
   deserialization (`pickle`, `yaml.load` without `SafeLoader`, `eval`).
3. **AuthN/AuthZ** — endpoints or handlers missing an auth check present
   on sibling endpoints; authorization checks that test the wrong
   scope/tenant/role; client-supplied IDs trusted without an ownership
   check.
4. **PHI/PII handling** (healthcare context — treat as high severity by
   default) — patient/member-identifying fields logged, written to
   non-encrypted storage, included in error messages/stack traces sent to
   third-party services, or returned in API responses beyond what the
   caller is authorized to see.
5. **Dependency risk** — a newly added dependency with a known CVE, or a
   version pin removed/loosened without explanation.
6. **Insecure defaults** — new config that disables TLS verification,
   widens CORS, or lowers a default timeout/rate-limit meaningfully.

## Output format

For each finding: `file:line — severity — issue — fix`. End with a one-line
summary (`N blocking, M warnings` or `no issues found`). Don't restate the
whole diff back to the user.
