#!/usr/bin/env bash
cat <<'EOF'
NON-NEGOTIABLE WORKFLOW REMINDER

Before any write/shell/subagent tool:
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
- Run the relevant checks or state exactly why they could not be run.
- Report changed files and the verification result.

If blocked:
- Stop before unsafe tool use.
- Explain the missing plan, permission, or prerequisite needed to continue.
EOF
