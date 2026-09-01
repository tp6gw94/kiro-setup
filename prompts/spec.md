---
description: Use subagents to gather context and write a structured specification
argument-hint: "[requirements]"
---

Apply the `spec-driven-development` and `subagent-orchestration` skills.

Requirements: ${ARGUMENTS:-Use the requirements from the current conversation}

## Kiro orchestration contract

Use the current `orchestrate_subagent` tool. Use one-stage calls when a human decision must occur between phases. Use only roles accepted by the current tool schema. The parent owns orchestration; every stage prompt must prohibit nested delegation.

## Workflow

1. Call `orchestrate_subagent` with one stage named `scout-context` using `role: "scout"`. Its prompt must cover the goal, cwd/ref, project rules, relevant files, existing architecture, actual build/test/lint commands, constraints, evidence locations, output format, and unresolved questions. It is read-only.
2. From the scout's evidence, list assumptions and ask the user one focused set of questions about target users, observable acceptance criteria, technical constraints, and Always / Ask first / Never boundaries.
3. If the request contains independently testable capabilities, make a separate `orchestrate_subagent` call with one stage named `capability-map` using `role: "reviewer"`. Ask it to propose stable module IDs, dependency direction, and build order. Present the result and obtain user approval.
4. Once requirements and any capability map are approved, make a separate `orchestrate_subagent` call with one stage named `write-spec` using `role: "planner"`. It writes `SPEC.md`; for a multi-module initiative, it writes the approved capability map and `SPEC-<module-id>.md` files. It may modify specification files only and may not write implementation code, commit, push, or delegate further.
5. Every stage prompt must include the outcome, cwd/ref, authority boundary, relevant files and decisions, success criteria, validation, output format, and blocked conditions.
6. The planner reports changed files, coverage of the six required sections, testable success criteria, open questions, and skipped validation. The parent inspects the diff, presents it for user approval, and stops.
