---
name: build
description: Use one worker to implement, test, verify, and commit incrementally. Load when the user asks to execute the next planned task, run a complete approved plan, or invokes build, build auto, or build all.
---

# Build

Apply the `incremental-implementation`, `test-driven-development`, `git-workflow-and-versioning`, and `subagent-orchestration` skills.

Mode comes from the current request:

- `build` completes the next pending task and stops.
- `build auto` (`all` is an alias) completes every pending task in dependency order after plan approval.

## Kiro orchestration contract

Use the current `orchestrate_subagent` tool. A bounded implementation run is one stage with `role: "worker"`. Use only role values accepted by the current tool schema. The parent owns orchestration; stage prompts must prohibit nested delegation.

## Shared rules

1. The parent retains requirements, approval, scope, and final acceptance. Keep one writer stage per cwd.
2. The worker prompt must include the outcome, cwd/ref, specification and plan paths, exact scope, allowed and forbidden files, acceptance criteria, RED/GREEN/REFACTOR expectations, repository-specific validation commands, commit authority, output format, and blocked conditions.
3. For each task, the worker reads the acceptance criteria, writes and confirms a failing test, makes the minimum implementation pass, runs focused tests, then the full suite and applicable build, typecheck, and lint commands. It updates task status, stages only that task's files plus its status update, and creates one descriptive commit when commit authority is granted.
4. The worker reports completed tasks, changed files, RED/GREEN evidence, commands and results, commits, remaining work, and risks. The parent inspects git status, the final diff, and the evidence before declaring completion.

## Single-task mode

After confirming that unrelated working-tree changes cannot be absorbed into the commit, call `orchestrate_subagent` with one stage named `implement-next` using the `worker` role. Stop when that task is complete.

## Auto mode

1. Require a specification at `SPEC.md`, `docs/SPEC.md`, or under `spec/*`. If none exists, stop and ask the user to create one.
2. Run `git status --porcelain`. If uncommitted changes exist outside expected specification or planning artifacts, ask the user how to handle them.
3. If `tasks/plan.md` is missing, run the `planning` workflow as a separate orchestration call.
4. Present the complete plan and obtain explicit approval. Do not start implementation before approval.
5. After approval, call `orchestrate_subagent` with one stage named `implement-plan` using the `worker` role. If this run created or changed planning files, the worker first commits only those artifacts when authorized, then executes pending tasks serially. Keep independent validation and one commit per task.
6. The worker returns a blocked result when tests or builds cannot pass, the specification is ambiguous, or work reaches authentication, payments, destructive migrations, deletion, deployment, secrets, or another high-risk or irreversible action. Resume only after the parent resolves the decision with the user.
