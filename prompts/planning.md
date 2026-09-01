---
description: Use a planner subagent to turn a specification into ordered, verifiable tasks
---

Apply the `planning-and-task-breakdown` and `subagent-orchestration` skills.

## Kiro orchestration contract

Use the current `orchestrate_subagent` tool with one stage named `plan` and `role: "planner"`. Use only role values accepted by the current tool schema. The parent owns orchestration; the stage prompt must prohibit nested delegation.

## Workflow

1. Identify the specification (`SPEC.md`, `docs/SPEC.md`, `spec/*`, or a user-supplied path) and planning scope. If no specification exists or a material requirement remains ambiguous, stop and ask the user.
2. Call `orchestrate_subagent` with the single `plan` stage. Its prompt must include the outcome, cwd/ref, specification path, relevant source files, project rules, permission to modify planning artifacts only, validation, output format, and blocked conditions. It must prohibit implementation, commits, pushes, and nested delegation.
3. The planner reads the specification and necessary code, then:
   - maps component dependencies and implementation order;
   - creates verifiable vertical slices;
   - gives every task acceptance criteria, validation, dependencies, and likely files;
   - splits tasks that would touch more than about five files;
   - adds a checkpoint after every two or three tasks;
   - writes `tasks/plan.md` and `tasks/todo.md`; if project rules require an external tracker, it uses that tracker and leaves an index in the plan.
4. The planner reports changed files, dependency order, risks, safe parallel work, validation, and open questions. The parent inspects the diff and completeness, then presents the plan for human review. Implementation must not begin before approval.
