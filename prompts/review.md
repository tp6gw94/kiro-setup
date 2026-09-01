---
description: Use parallel fresh-context reviewers for a five-axis code review
argument-hint: "[diff, commit, or scope]"
---

Apply the `code-review-and-quality` and `subagent-orchestration` skills, plus the relevant security or performance skill when those risks exist.

Review target: ${ARGUMENTS:-Use the current staged and unstaged diff; if empty, use recent commits}

## Kiro orchestration contract

Use one `orchestrate_subagent` call with three independent stages. Stages without `depends_on` start in parallel. Use only roles accepted by the current tool schema. The parent owns orchestration; every stage prompt must prohibit nested delegation.

## Workflow

1. Identify the exact diff/ref, specification or task contract, and changed files.
2. Call `orchestrate_subagent` with these independent stages, each using `role: "reviewer"` and no `depends_on`:
   - `correctness-tests`: correctness, boundaries, error paths, regressions, and test effectiveness;
   - `architecture-simplicity`: readability, project conventions, architecture boundaries, duplication, and over-engineering;
   - `security-performance`: trust boundaries, auth/authz, secrets, injection, dependency risk, N+1 behavior, and unbounded work.
3. Every stage must inspect the target diff and source directly. Its prompt must include the outcome, cwd/ref, read-only authority, relevant specification, evidence bar, completion criteria, output format, and blocked conditions. Reviewers may not modify files, delegate further, or promote speculation to a blocker.
4. Report only concrete, currently reachable issues caused or exposed by the change. Include `file:line`, evidence, the smallest safe fix, and P0/P1/P2 severity. End every stage report with `Merge verdict: BLOCK`, `Merge verdict: OK`, or `Merge verdict: OK with notes`.
5. After the orchestration call returns, the parent deduplicates findings and classifies each against current HEAD as valid blocker, valid non-blocker, stale, invalid, out-of-scope, or speculative. A stage verdict is evidence, not merge authority.
6. Return a structured review ordered by severity, including performed and skipped validation plus the final recommendation. This workflow is review-only unless the user explicitly asks for fixes.
