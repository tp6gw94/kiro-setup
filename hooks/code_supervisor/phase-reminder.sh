#!/usr/bin/env bash
cat <<'EOF'
NON-NEGOTIABLE WORKFLOW REMINDER

Before any write/subagent tool:
1. Understand the user's newest request and ignore stale goals that conflict with it.
2. Check whether a concrete .plan/<task>/task.md exists when the task requires implementation or source edits.
3. Choose the path: plan-only work, source-writing work, or read-only investigation.

Delegation check:
- If specialist work is useful, launch the right subagent in the same turn.
- If no delegation is useful, say why briefly before continuing.
- Keep code_supervisor writes inside .plan/; source edits belong to source-writing agents with an active plan.

Execute:
- Split independent work so it can run in parallel.
- Keep the next blocking step local instead of waiting on a subagent unnecessarily.

Verify before final:
- Do not run source/build/test/lint/typecheck verification yourself.
- Read .plan artifacts only: dev-notes.md, simplifier-notes.md, test-notes.md when required, and review.md.
- If verification evidence is missing or weak, delegate tester or reviewer instead of using shell.
- Report changed files and verification results from specialist notes.

If blocked:
- Stop before unsafe tool use.
- Explain the missing plan, permission, or prerequisite needed to continue.
EOF
