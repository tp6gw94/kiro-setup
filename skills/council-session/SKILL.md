---
name: council-session
description: Multi-model consensus via subagent DAG. Use when you need diverse model perspectives on complex architectural decisions, high-stakes code changes, or ambiguous trade-offs.
---

# Council Session

Run a multi-model council to get diverse AI perspectives on a complex problem.

## When to Use
- Critical architectural decisions needing diverse model perspectives
- High-stakes code changes where consensus reduces risk
- Ambiguous problems where multi-model disagreement is informative
- Security-sensitive design reviews

## When NOT to Use
- Straightforward tasks you're confident about
- Speed matters more than confidence
- Routine implementation work

## Pre-built Agents

The following agents are pre-configured with different models in `~/.kiro/agents/`:

| Agent | Model | Role |
|-------|-------|------|
| `councillor-a` | `claude-opus-4.6` | Strong reasoning, deep analysis |
| `councillor-b` | `glm-5` | Different training data, different biases |
| `councillor-c` | `claude-opus-4.5` | Balanced reasoning, prior generation perspective |
| `council-master` | `claude-opus-4.6` | Synthesizes all councillor outputs |

All councillors are read-only (can read files, grep, glob but cannot edit). The council-master is pure synthesis.

To change models, re-run `~/.kiro/generate-configs.sh` after editing the model values in the script.

## How to Run a Council

You (code_supervisor) construct a 4-stage subagent call:
- 3 parallel councillor stages (no dependencies — they run simultaneously)
- 1 council-master stage that `depends_on` all 3 councillors

## Example Subagent Call

```json
{
  "task": "<describe the problem/decision here>",
  "stages": [
    {
      "name": "councillor-a",
      "role": "councillor-a",
      "prompt_template": "{task}"
    },
    {
      "name": "councillor-b",
      "role": "councillor-b",
      "prompt_template": "{task}"
    },
    {
      "name": "councillor-c",
      "role": "councillor-c",
      "prompt_template": "{task}"
    },
    {
      "name": "council-master",
      "role": "council-master",
      "depends_on": ["councillor-a", "councillor-b", "councillor-c"],
      "prompt_template": "Synthesize the optimal response for:\n{task}"
    }
  ]
}
```

Each councillor's system prompt is already defined in its `.md` file. The `prompt_template` only needs the problem description — use `{task}` to pass through the overall task.

## Result Handling
Present the council master's synthesized response verbatim to the user. Do not re-summarize — the council master has already produced the final answer.
