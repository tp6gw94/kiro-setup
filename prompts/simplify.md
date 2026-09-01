---
description: Use reviewer -> worker -> reviewer to simplify recent changes without changing behavior
argument-hint: "[scope]"
---

Apply the `code-simplification`, `ponytail`, and `subagent-orchestration` skills.

Scope: ${ARGUMENTS:-Use recent changes}

## Kiro orchestration contract

Use one `orchestrate_subagent` call with explicit stage dependencies. Use only roles accepted by the current tool schema. The parent owns orchestration; every stage prompt must prohibit nested delegation.

## Workflow

1. Call `orchestrate_subagent` with these stages:
   - `inspect`, `role: "reviewer"`, no dependency: inspect the target diff, AGENTS.md, callers, boundaries, and tests; propose only behavior-preserving simplifications or return no-change;
   - `simplify`, `role: "worker"`, `depends_on: ["inspect"]`: apply only evidence-backed, in-scope changes; if `inspect` found no safe simplification, make no edits and return no-change;
   - `validate`, `role: "reviewer"`, `depends_on: ["simplify"]`: inspect the final source and diff for behavior, error-handling, convention, and scope regressions.
2. Every stage prompt must include the outcome, cwd/ref, exact scope, authority boundary, relevant files and evidence, success criteria, validation, output format, and blocked conditions.
3. Only the `simplify` stage may write in the cwd. The review stages are read-only. The worker runs focused tests incrementally, then the full suite and applicable build, typecheck, and lint commands. It must not change tests to hide behavior changes.
4. Prefer deleting ineffective abstractions, reusing existing helpers or the standard library, and reducing nesting or duplication. Avoid adjacent cleanup, speculative abstractions, and weakened validation or error handling.
5. If a test fails or behavior equivalence cannot be established, return a blocked result with evidence instead of guessing. After the orchestration call returns, the parent inspects the final diff, validation results, and reviewer findings, then reports changed files, reduced complexity, and residual risks.
