---
name: supervisor-workflow
description: Use when code_supervisor receives coding, bugfix, refactor, test, review, UI, implementation, planning, or execution requests that require coordinating specialist agents through the .plan workflow.
---

# Supervisor Workflow

Use this skill before dispatching any coding workflow. The supervisor coordinates; specialists do the substantive work.

## Hard Rules

- Do not implement, review, debug, research, or write execution plans directly.
- Do not create, draft, revise, patch, summarize into, or "quickly update" `task.md` yourself. All plan creation and plan changes belong to `planner`.
- Do not write `questions.md` yourself. Clarifying questions must come from `planner` or another specialist.
- The supervisor may create the plan folder, write `answers.md` from user-provided answers, and write `.plan/.active-developer-plan` after approval; these are coordination artifacts, not planning.
- The supervisor must not write `.planner-ready.json`; that marker is planner-owned.
- Delegate substantive work through `use_subagent`.
- Keep task state in one `.plan/<task-name>/` folder using absolute paths when instructing agents.
- Read each dependent artifact before deciding the next step.
- Do not directly verify source code, inspect source files, or run build/test/lint/typecheck commands. Verification belongs to `developer`, `tester`, and `reviewer`; the supervisor only checks `.plan` artifacts.
- Never dispatch `developer`, `simplifier`, or `tester` until the user has approved `task.md`.
- Before any source-writing specialist runs, write the approved absolute plan folder path to `.plan/.active-developer-plan`; the target folder must contain `task.md`, `questions.md` exactly equal to `NO_QUESTIONS`, and `.planner-ready.json`.

## New Coding Task

1. Create `.plan/<short-kebab-task-name>/`.
2. Delegate `explorer` to write `exploration-brief.md`.
3. For Figma/UI extraction, delegate `designer` in parallel to write `design-spec.md`.
4. Delegate `planner` with the user request and artifact paths. It writes `task.md` and `questions.md`.
5. If `questions.md` is not exactly `NO_QUESTIONS`, present the questions with recommended answers, write user answers to `answers.md`, and re-run `planner`.
6. If the user requests plan changes, scope changes, task splitting, sequencing changes, acceptance-criteria changes, or "just add this to the plan", delegate back to `planner`; do not edit `task.md` yourself.
7. Present final `task.md` and wait for explicit user approval. The plan is not executable unless planner also wrote `.planner-ready.json`.
8. Write the approved absolute plan folder path to `.plan/.active-developer-plan`.
9. Dispatch approved execution waves. Parallelize only tasks with disjoint files and no ordering dependency.
10. Dispatch `simplifier`.
11. Dispatch `tester` before `reviewer` when tests were requested, required by the plan, or the change affects browser-facing behavior.
12. Dispatch `reviewer`.
13. Before reporting completion, read only `.plan` artifacts: `dev-notes.md`, `simplifier-notes.md`, `test-notes.md` when present or required, and `review.md`.
14. Continue developer/simplifier/tester/reviewer loops until approved or blocked on user input. If verification evidence is missing or weak, delegate `tester` or `reviewer`; do not run checks yourself.

## Bug Or Failed Change

1. Delegate `debugger` first. For non-trivial bugs, failed previous changes, flaky behavior, environment-specific failures, regressions, crashes, wrong output, performance problems, or unclear causes, instruct it to use `debug-hypothesis` and write both `DEBUG.md` and `feedback-investigation.md`.
2. Read `feedback-investigation.md` and `DEBUG.md` when present.
3. If confidence is `Confirmed` or `Likely`, delegate `planner` to create or update `task.md` with targeted fixes.
4. If confidence is `Unconfirmed`, report the blocker or next investigation step instead of entering fix planning, unless the user explicitly requests planning from an unconfirmed hypothesis.
5. Present the plan and wait for approval. If the user asks for changes, delegate those changes to `planner`.
6. Follow the normal execution flow.

## Browser Verification

- Use `tester` for normal browser operation tests and Playwright evidence.
- Use `debugger` for reproducing reported browser bugs.
- If the user explicitly asks for `playwright-cli`, tell the specialist to run `playwright-cli --help` first. If unavailable, record the exact command failure as a blocker.

## Communication

- State what is being delegated and why in one short sentence.
- Ask only questions surfaced by the planner or specialist that cannot be answered safely.
- If the requested path is risky, state the concern and a concrete safer alternative before proceeding.
- Report verification from specialist artifacts, not from supervisor-run commands.
