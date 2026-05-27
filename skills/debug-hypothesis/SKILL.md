---
name: debug-hypothesis
description: Use when investigating non-trivial bugs, failed previous changes, flaky behavior, environment-specific failures, regressions, crashes, wrong output, or performance problems with unclear cause.
reference: https://github.com/LichAmnesia/lich-skills/blob/main/skills/debug-hypothesis/SKILL.md
---

# Hypothesis-Driven Debugging

Use a scientific loop for difficult debugging: observe facts, form competing hypotheses, run one minimal experiment, then conclude. Guessing is not debugging.

## When To Use

Use for non-trivial bugs, failed fixes, flaky tests, local-vs-CI differences, crashes with unclear cause, wrong output, regressions, and performance problems.

Do not use for typos, missing imports, syntax errors, or compiler/linter messages that identify the exact single-line fix.

## Artifacts

Write the full trail to `.plan/<task>/DEBUG.md`:

```markdown
## Observations
## Hypotheses
## Experiments
## Root Cause
## Fix Direction
```

Then write the planner-facing summary to `.plan/<task>/feedback-investigation.md`.

The debugger does not edit production source. Diagnostic experiments may temporarily change at most 5 lines and must be reverted before finishing.

## Loop

### 1. Observe

- Reproduce the issue, or record why it could not be reproduced.
- Capture exact error messages, stack traces, wrong output, command output, browser steps, URLs, logs, and environment details.
- Identify the minimal reproduction and the boundary between working and broken behavior.
- Write raw facts to `DEBUG.md` under `## Observations`.

Exit only after the bug is reproduced or non-reproduction is documented with conditions.

### 2. Hypothesize

Write 3-5 possible root causes in `DEBUG.md`. For each:

- `Supports:` evidence that fits.
- `Conflicts:` evidence that argues against it.
- `Test:` one minimal experiment that would prove or disprove it.

Mark one `ROOT HYPOTHESIS`: the hypothesis with the best support and least conflicting evidence, preferring the easiest one to test.

### 3. Experiment

Before running the experiment, write:

- what will change,
- what result confirms the hypothesis,
- what result rejects it.

Rules:

- One variable per experiment.
- Maximum 5 changed lines.
- Prefer logs, assertions, hardcoded values, or short-circuits.
- Do not write the production fix.
- Revert experimental changes after recording results.

Record the result as `confirmed`, `rejected`, or `inconclusive` in `DEBUG.md`.

### 4. Conclude

If the root hypothesis is confirmed:

- Write the root cause in one sentence.
- Include exact file and line references.
- Write behavioral fix guidance, not implementation code.
- Set `Confidence` in `feedback-investigation.md` to `Confirmed`.

If not confirmed:

- Promote the next hypothesis and repeat the experiment phase.
- If all hypotheses are rejected, return to observation and state what is missing.
- Set `Confidence` to `Likely` only when evidence strongly supports a cause despite incomplete reproduction.
- Set `Confidence` to `Unconfirmed` when the evidence is insufficient; do not present a targeted fix as certain.

## `feedback-investigation.md` Format

```markdown
## Reported Issue
<summary>

## Evidence
- Debug trail: /absolute/path/to/.plan/<task>/DEBUG.md
- Artifacts reviewed:
- Files traced:
- Commands run:
- Browser reproduction steps, if applicable:

## Root Hypothesis
<hypothesis tested and result>

## Root Cause
<confirmed or likely cause with /path:line references, or unconfirmed reason>

## Affected Files
- /absolute/path:line - why it needs change

## Fix Direction
<behavioral fix guidance, or next investigation step if unconfirmed>

## Confidence
Confirmed | Likely | Unconfirmed, with reason
```

## Anti-Bulldozer Rules

- Do not write more than 5 diagnostic lines before confirming a hypothesis.
- Do not try the same hypothesis twice after rejection.
- Do not ignore conflicting evidence.
- Do not plan or implement fixes until `feedback-investigation.md` contains a root cause with `Confirmed` or `Likely` confidence.
