---
name: subagent-orchestration
description: Use whenever the user assigns a complex task, explicitly requests subagents or multi-agent delegation, or names or refers to any available subagent role. Guides Kiro in selecting roles, writing complete dispatch contracts, building dependency-aware pipelines, and synthesizing results.
---

# subagent-orchestration

Use this skill when Kiro needs to delegate work to one or more subagents, choose an agent role, build a multi-agent pipeline, or decide whether a task should remain in the main session. The goal is **bounded delegation**: each agent gets one clear responsibility, the evidence it needs, and a checkable completion criterion.

## Source of truth

Before dispatch, treat the current subagent tool's accepted `role` values as authoritative. Agent files describe behavior; the tool schema determines which roles can actually be dispatched. If they differ, use only tool-supported roles and report the mismatch.

## Choose the smallest useful delegation

1. Keep the task in the main session when it is trivial, conversational, or cheaper than preparing a handoff.
2. Use one subagent for a self-contained task with one output.
3. Use a pipeline only when distinct specialties, parallel investigation, an implementation/review boundary, or a fresh-context decision check materially improves the result.
4. Keep one writer thread. Parallelize independent investigation and review, not overlapping edits.

Completion criterion: every dispatched stage has a distinct purpose that could not be removed without weakening correctness, coverage, or latency.

## Dispatchable roles

### Core roles

- `scout` — fast, targeted codebase reconnaissance. Use to map entry points, symbols, data flow, likely files, and constraints before another agent acts. Prefer it when the question is **where and how does this area work?** It returns compressed context and does not edit source.
- `context-builder` — deep requirements-to-codebase analysis. Use when the next agent needs a complete handoff, external evidence, implementation risks, and a meta-prompt contract. Prefer it over `scout` when the task is ambiguous, cross-cutting, or expensive to rediscover. It may write only requested context artifacts, not source code.
- `planner` — turns approved requirements and gathered context into a spec, implementation plan, or ordered task list. It reads source but writes only planning artifacts. Use after context is sufficient; planning is not a substitute for reconnaissance.
- `researcher` — focused external research using primary sources, official documentation, current APIs, benchmarks, or recent developments. Use when local code cannot establish the answer. Ask for citations and explicit gaps. It writes research artifacts only.
- `oracle` — read-only consistency check. Use before a risky pivot, when a proposal may contradict inherited decisions, or when accumulated context may be causing drift. It recommends; it does not execute. `advisor` is a compatibility alias with identical behavior, so choose one, never both for the same check.
- `worker` — implementation agent and default writer. Give it an approved direction, exact inputs, boundaries, and validation requirements. It may edit source and run checks. Use one worker for one coherent write set unless tasks are isolated by file ownership or worktree.
- `reviewer` — evidence-based review of diffs, plans, proposals, PRs/issues, or codebase health. Use after implementation or as an independent review. State whether it is review-only or may apply small corrective fixes; review-only wins when instructions conflict.
- `semantic_reviewer` — behavior- and design-level review organized by concern rather than file. Use when reviewers need the narrative, architectural implications, or cross-file behavior of a change. Pair with `reviewer` only when both semantic and line-level review are worth their cost.
- `delegate` — lightweight general-purpose agent for a small, well-scoped, self-contained task. It has no inherited context or ambient MCP tools. Include every required input in the prompt. Prefer this over a pipeline for one-off bounded work.

### Agent profiles that are not normal subagents

These files may exist under `~/.kiro/agents`, but they are runtime profiles rather than ordinary pipeline roles:

- `my-default` from `default.md` — default interactive agent configuration.
- `main` — coordinating session; explicitly excluded from delegation.

Invoke these only through their owning runtime or service. Do not pass them as a pipeline role unless the current tool schema explicitly supports them.

## Write a complete dispatch contract

Every stage prompt must contain:

- **Outcome** — one concrete deliverable.
- **Scope** — what is included and excluded.
- **Inputs** — exact paths, URLs, prior-stage artifacts, decisions, or evidence to read.
- **Constraints** — permissions, invariants, ownership boundaries, and whether edits are allowed.
- **Validation** — tests, checks, citations, or review evidence required.
- **Done** — a checkable, exhaustive completion criterion.
- **Blocked** — conditions that require returning a blocked result instead of guessing.
- **Output** — expected response or artifact path and format.

Subagents have no live clarification channel. Resolve decisions before dispatch, or instruct the agent to stop with the exact decision needed, options, tradeoffs, and recommendation.

## Build the pipeline

1. Decompose by responsibility, not by arbitrary file count. Each stage owns one outcome.
2. Start independent read-only stages in parallel. Use dependencies only when a stage genuinely needs an earlier stage's output.
3. Name every required dependency. A stage sees the overall task and outputs from its declared dependencies; it must not rely on hidden session context.
4. Pass distilled evidence forward. Do not ask downstream agents to rediscover files, decisions, or sources already established upstream.
5. Put decision gates before writes. If requirements or architecture remain unapproved, finish with a plan, oracle recommendation, or blocked result rather than dispatching a worker.
6. Use a single writer for overlapping files. After writing, dispatch review against the actual diff and validation evidence.
7. The main session synthesizes outputs, resolves conflicts, verifies completion, and reports to the user. Delegation does not transfer final responsibility.

Completion criterion: the dependency graph carries every required input to each stage, no two stages ambiguously own the same mutation, and the final stage proves the user's requested outcome.

## Reliable patterns

### Small bounded task

`delegate`

Give all context directly. Use for a single lookup, transformation, isolated edit, or concise analysis.

### Normal code change

`scout` → `worker` → `reviewer`

Add `planner` between scout and worker when requirements span multiple independently testable steps or need approval.

### Ambiguous or cross-cutting change

`context-builder` → `planner` → optional `oracle` → `worker` → `reviewer`

Use `oracle` only for decision consistency or risky pivots, not as a routine approval ceremony.

### Research-backed implementation

Run `context-builder` and `researcher` in parallel → `planner` → `worker` → `reviewer`.

The planner must depend on both research stages so local and external evidence are reconciled before implementation.

### High-value review

Run `reviewer` and `semantic_reviewer` in parallel, then synthesize overlapping findings by evidence and severity. Do not duplicate both reviews for small diffs.

## Final checks

Before accepting the pipeline result, verify:

- every requested deliverable exists in the expected place or response;
- implementation stages changed only their owned scope;
- validation evidence is current and relevant;
- reviewers inspected actual source or diffs rather than summaries alone;
- blocked results are surfaced, not presented as success;
- conflicting agent recommendations are resolved by the main session against requirements and evidence.
