# Kiro CLI Configuration

Multi-agent AI coding orchestrator powered by Kiro CLI. Features 16 specialized agents, 6 custom hooks, 24 skills, and a code-gen config pipeline.

## Architecture Overview

```
                        ┌─────────────────┐
                        │ code_supervisor  │  (ctrl+a)
                        │   orchestrator   │
                        └────────┬────────┘
                                 │ subagent tool
            ┌────────────────────┼────────────────────┐
            ▼                    ▼                     ▼
   ┌─────────────────┐  ┌──────────────┐  ┌────────────────────┐
   │   10 leaf agents │  │  4 council   │  │  .plan/ folder     │
   │   (specialists)  │  │  agents      │  │  (inter-agent IPC) │
   └─────────────────┘  └──────────────┘  └────────────────────┘
```

- `code_supervisor` is the orchestrator — dispatches to leaf agents via the `subagent` tool
- 10 leaf agents: developer, reviewer, designer, explorer, simplifier, tester, debugger, planner, librarian, researcher
- 4 council agents: councillor-a, councillor-b, councillor-c, council-master (multi-model consensus)
- All agent prompts use XML tag format (`<Role>`, `<Agents>`, `<Workflow>`, etc.)

## Quick Start

### Prerequisites

- `jq` (JSON processing)
- Node.js (for `npx` — MCP servers)
- Python 3 (for `uvx` — MCP servers)
- `rtk` (Rust Token Killer) — required for token-optimized shell command execution. Install from [https://github.com/rtk-ai/rtk](https://github.com/rtk-ai/rtk)
- `cmux` (optional) — native macOS terminal for AI coding agents. Enables desktop notifications. Install from [https://github.com/manaflow-ai/cmux](https://github.com/manaflow-ai/cmux)
- `EXA_API_KEY` environment variable (for Exa search)

### Installation

```bash
# 1. Clone/copy this directory
cp -r .kiro ~/.kiro

# 2. Generate agent JSON configs from markdown prompts
chmod +x ~/.kiro/generate-configs.sh
~/.kiro/generate-configs.sh

# 3. Start
kiro-cli chat   # defaults to code_supervisor agent
```

**Customization:** To change the response language, edit `hooks/locale.sh`. The default is set to Traditional Chinese (繁體中文).

## Agents

### Leaf Agents

| Agent | Role | Model | Shortcut |
|-------|------|-------|----------|
| developer | Code implementation | claude-opus-4.6 | `ctrl+shift+d` |
| reviewer | Code review & YAGNI enforcement | claude-opus-4.6 | `ctrl+r` |
| designer | Figma design extraction | claude-opus-4.6 | `ctrl+shift+f` |
| explorer | Codebase investigation | claude-opus-4.6 | `ctrl+e` |
| simplifier | Code refinement | claude-opus-4.6 | `ctrl+shift+s` |
| tester | Test suite design | claude-opus-4.6 | `ctrl+t` |
| debugger | Root cause investigation | claude-opus-4.6 | `ctrl+b` |
| planner | Execution plans | claude-opus-4.6 | `ctrl+p` |
| librarian | Library docs research | claude-opus-4.6 | `ctrl+l` |
| researcher | Academic paper search | claude-opus-4.6 | `ctrl+shift+r` |

### Orchestrator

| Agent | Role | Model | Shortcut |
|-------|------|-------|----------|
| code_supervisor | Orchestrator — dispatches to all leaf agents | claude-opus-4.6 | `ctrl+a` |

### Council Agents

| Agent | Model | Role |
|-------|-------|------|
| councillor-a | claude-opus-4.6 | Independent perspective A |
| councillor-b | GLM-5 | Independent perspective B |
| councillor-c | claude-opus-4.5 | Independent perspective C |
| council-master | claude-opus-4.6 | Synthesizes council consensus |

## Hooks

6 hooks total — 4 base hooks for all agents + 2 supervisor-only hooks.

| Hook | Trigger | Scope | Description |
|------|---------|-------|-------------|
| `rtk-rewrite.sh` | `preToolUse` (shell) | Most agents | Intercepts shell commands, rewrites via RTK for token efficiency. Blocks original and suggests rtk-prefixed version. |
| `rtk-rules.sh` | `agentSpawn` | Most agents | Injects RTK usage instructions into agent context at startup |
| `caveman.sh` | `agentSpawn` | All agents | Injects caveman speech style instruction |
| `locale.sh` | `agentSpawn` | All agents | Injects Traditional Chinese (繁體中文) locale instruction |
| `phase-reminder.sh` | `userPromptSubmit` | code_supervisor | Reminds orchestrator of 6-phase workflow on every prompt |
| `cmux-notify.sh` | `stop` | code_supervisor | Desktop notification via cmux when response completes |

## RTK Integration

RTK (Rust Token Killer) is a CLI proxy that optimizes shell command output for token efficiency. Two-layer protection ensures agents always use it:

1. **`agentSpawn` hook** (`rtk-rules.sh`) — tells agents to use `rtk` prefix for shell commands at startup
2. **`preToolUse` hook** (`rtk-rewrite.sh`) — intercepts and rewrites commands if agents forget

> **Important:** `agentSpawn` hooks do NOT fire for subagent sessions, but `preToolUse` hooks DO. This is why both layers are needed.

## Skills

| Skill | Description |
|-------|-------------|
| cartography | Generate hierarchical codemaps for unfamiliar repositories |
| council-session | Multi-model consensus via subagent DAG |
| simplifier | Code refinement and complexity reduction |
| get-code-context-exa | Code context search via Exa (GitHub, StackOverflow, docs) |
| web-search-advanced-research-paper-exa | Academic paper search via Exa |
| [Caveman](https://github.com/juliusbrussee/caveman) | ~75% output token reduction via terse caveman-speak. 5 sub-skills (caveman, caveman-commit, caveman-compress, caveman-help, caveman-review). Intensity levels: `lite`, `full` (default), `ultra`. Also injected via `hooks/caveman.sh` for persistent caveman speech across all agents. |
| [Grill Me](https://github.com/mattpocock/skills/blob/main/grill-me/SKILL.md) | Interview/stress-test skill — relentlessly grills you on plans and designs, walking each branch of the decision tree until reaching shared understanding |

> **Additional skills** available at [github.com/vercel-labs/skills](https://github.com/vercel-labs/skills)

## cmux Integration

[cmux](https://github.com/manaflow-ai/cmux) is a native macOS terminal application built on top of Ghostty (libghostty), designed for developers running multiple AI coding agents in parallel. It provides notification rings, workspace management, and a scriptable CLI — purpose-built for agent workflows.

### Install

**Homebrew:**
```bash
brew tap manaflow-ai/cmux
brew install --cask cmux
```

**Or download the DMG:** [cmux-macos.dmg](https://github.com/manaflow-ai/cmux/releases/latest/download/cmux-macos.dmg)

**CLI setup** (for use outside cmux terminals):
```bash
sudo ln -sf "/Applications/cmux.app/Contents/Resources/bin/cmux" /usr/local/bin/cmux
```

### How it's used here

The `cmux-notify.sh` hook (triggered on `stop` for `code_supervisor`) sends a desktop notification via `cmux notify` whenever the orchestrator finishes responding. The cmux sidebar tab lights up with a blue notification ring showing the project name and a preview of the response — useful when managing multiple Kiro CLI sessions across workspaces.

The hook includes a guard clause (`cmux ping || exit 0`) so it silently does nothing if cmux is not installed or not running.

## MCP Servers

| Server | Transport | Description |
|--------|-----------|-------------|
| git | `uvx mcp-server-git` | Git operations |
| context7 | `npx @upstash/context7-mcp` | Library documentation lookup |
| figma-developer-mcp | `npx figma-developer-mcp` | Figma design extraction |
| [exa](https://github.com/exa-labs/exa-mcp-server) | Remote URL | Web search and research |
| github-grep | Remote URL (`mcp.grep.app`) | GitHub code search |

## Configuration Pipeline

`generate-configs.sh` is the single source of truth.

```
  .md prompt files ──┐
                     ├──▶ generate-configs.sh ──▶ .json agent configs
  .sh hook scripts ──┘         (runtime)           (gitignored)
```

- `.md` prompt files and `.sh` hook scripts are **git-tracked**
- `.json` agent configs are **generated at runtime** (gitignored)
- Hook injection: 4 base hooks applied to all agents + 2 supervisor-only hooks

## Plan Folder Protocol

`.plan/<task-name>/` is the inter-agent communication directory. Agents read and write standardized files to coordinate work.

| File | Purpose |
|------|---------|
| `exploration-brief.md` | Explorer's codebase analysis |
| `task.md` | Full task requirements |
| `questions.md` | Planner's clarifying questions |
| `answers.md` | User's answers to questions |
| `dev-notes.md` | Developer's implementation notes |
| `design-spec.md` | Designer's UI specification |
| `simplifier-notes.md` | Simplifier's refinement notes |
| `test-notes.md` | Tester's test plan |
| `review.md` | Reviewer's code review |
| `feedback-investigation.md` | Debugger's investigation |
| `librarian-research.md` | Librarian's research findings |

## Settings

| Setting | Value |
|---------|-------|
| Default agent | `code_supervisor` |
| Default model | `claude-opus-4.6` |
| Thinking mode | Enabled |
| Tangent mode | Enabled |
| Diff tool | `delta --side-by-side --paging=never` |

## Key Design Patterns

1. **Code-gen over config** — markdown prompts are the source of truth; JSON configs are generated
2. **Hook injection** — behavior injected at runtime via shell hooks, not baked into prompts
3. **Separation of concerns** — each agent has a single responsibility
4. **Plan folder protocol** — standardized file-based IPC between agents
5. **Parallel wave execution** — supervisor dispatches independent tasks concurrently
6. **Multi-model council consensus** — diverse models debate for high-stakes decisions
