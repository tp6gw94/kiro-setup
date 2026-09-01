---
description: Use parallel specialist reviewers to produce a launch GO/NO-GO decision and rollback plan
argument-hint: "[diff, commit, or release scope]"
---

Apply the `shipping-and-launch` and `subagent-orchestration` skills.

Launch scope: ${ARGUMENTS:-Use the current staged and unstaged diff; if empty, use recent commits}

`/ship` is a read-only pre-launch gate. It must not deploy, push, merge, release, or modify project files without separate explicit user authorization.

## Kiro orchestration contract

Use one `orchestrate_subagent` call with three independent stages. Stages without `depends_on` start in parallel. Use only roles accepted by the current tool schema. The parent owns orchestration; every stage prompt must prohibit nested delegation.

## Phase A — Specialist review

1. Identify the exact ref/diff, specification, changed files, deployment target, and available validation commands.
2. Call `orchestrate_subagent` with these independent stages, each using `role: "reviewer"` and no `depends_on`:
   - `code-quality`: correctness, readability, architecture, performance, and regressions;
   - `security`: threat model, OWASP risks, auth/authz, secrets, data boundaries, and dependency risk;
   - `test-operability`: coverage, failure paths, migrations, config/env, observability, rollout, and rollback gaps.
3. Every stage prompt must include the outcome, cwd/ref, read-only authority, relevant specification and files, evidence bar, completion criteria, output format, and blocked conditions. Reviewers may not modify files or delegate further. Findings require `file:line` or verifiable configuration or command evidence.

Skip orchestration only when all conditions hold: no more than two changed files, fewer than 50 changed lines, and no authentication, payments, data access, migration, or config/env changes. In that case, the parent performs the same checklist directly.

## Phase B — Parent validation and synthesis

After the orchestration call returns, inspect specialist evidence and run the repository's actual tests, build, typecheck, lint, or focused checks. Stage claims do not prove that commands passed. Also verify accessibility, env and migrations, monitoring, feature flags, documentation, and exact-head status. Deduplicate findings against current HEAD. Critical or high-severity security and data-integrity issues are blockers by default.

## Phase C — Decision

Return:

```markdown
## Ship Decision: GO | NO-GO

### Blockers
- [source: issue, evidence, location]

### Recommended fixes
- [issue and smallest safe fix]

### Acknowledged risks
- [risk and mitigation]

### Verification
- [commands and results; skipped checks]

### Rollback plan
- Trigger conditions: [...]
- Procedure: [...]
- Recovery time objective: [...]

### Specialist summaries
- [three summaries]
```

A GO decision requires an executable rollback plan. Any Critical finding defaults to NO-GO unless the user explicitly accepts the risk. Reviews and checks provide evidence, not launch authority.
