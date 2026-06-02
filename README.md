# Kiro CLI Configuration

Personal Kiro CLI setup for a delegated multi-agent coding workflow. The generated runtime config currently defines 14 agents, 13 runtime hooks, 10 tracked local skills, and a small MCP layer for search, Git, browser, Figma, and local filesystem operations.

The source of truth is the tracked markdown, hook, skill, and script files in this directory. Generated JSON config is intentionally not tracked.

## Quick Start

### Prerequisites

| Requirement | Purpose |
|-------------|---------|
| `jq` | Builds generated JSON config |
| Node.js / `npx` | Runs Context7, Figma, and optional Chrome DevTools MCP servers |
| Python 3 / `uvx` | Runs the Git MCP server |
| `EXA_API_KEY` | Enables Exa search MCP servers |
| `rtk` | Token-optimized shell command proxy |
| `cmux` | Optional desktop notifications and markdown preview panels |

### Install

```bash
cp -r .kiro ~/.kiro
export EXA_API_KEY="your-key-here"
chmod +x ~/.kiro/generate-configs.sh
~/.kiro/generate-configs.sh
kiro-cli chat
```

The default response language is Traditional Chinese. Change it in `hooks/locale.sh`.

### Docker Sandbox Configs

This repo has a custom Docker Sandbox template and a local Kiro mixin kit.

Build and load the template once:

```bash
./build-kiro-sandbox-template.sh kiro-sandbox-template:v1
docker image save kiro-sandbox-template:v1 -o kiro-sandbox-template.tar
sbx template load kiro-sandbox-template.tar
```

Create and run a sandbox from this repo:

```bash
kiro-sandbox-run
```

`kiro-sandbox-run` creates a named sandbox, then runs it:

```bash
sbx create -t kiro-sandbox-template:v1 --kit "$HOME/.kiro/kits/kiro-sandbox" --name <name> kiro <workspace-path>
sbx run <name>
```

Generated sandbox names use `r-<8 hex>`. Use `--name` for a stable name, or
`--existing` to skip creation:

```bash
kiro-sandbox-run --name r-dev
kiro-sandbox-run --existing r-dev
```

Arguments after `--` are passed to `sbx run <name>`:

```bash
kiro-sandbox-run --name r-dev -- chat --trust-all-tools --resume
```

`kiro-sandbox-run` starts a shared local cmux notify bridge if one is not
already listening on port `17363`, then injects the current `cmux identify`
target into the sandbox. If `cmux identify` is unavailable, the cmux notify
setup is skipped and the sandbox still starts normally. To start the bridge
manually:

```bash
node ~/.kiro/kits/kiro-sandbox/cmux-notify-bridge.mjs --host 0.0.0.0 --port 17363
```

Bridge logs are written to `~/.kiro/logs/cmux-notify-bridge.log`:

```bash
tail -f ~/.kiro/logs/cmux-notify-bridge.log
```

The sandbox sends `CMUX_NOTIFY_SURFACE`/`CMUX_NOTIFY_WORKSPACE` in each notify
payload so multiple sandboxes can share the same bridge without port conflicts.
To override the target manually inside a sandbox, update `/etc/sandbox-persistent.sh`:

```bash
sbx exec -d <sandbox-name> bash -c "echo 'export CMUX_NOTIFY_SURFACE=surface:1' >> /etc/sandbox-persistent.sh"
```

The sandbox kit sets `CMUX_NOTIFY_URL` to
`http://host.docker.internal:17363/notify` as the baseline notification
endpoint. `kiro-sandbox-run` only refreshes the cmux target metadata. If your
runtime cannot resolve `host.docker.internal`, run with
`CMUX_NOTIFY_URL=http://<host-ip>:17363/notify` so the injected value uses your
host LAN IP.

For Ralph iterations, use `ralph-sandbox-loop`:

```bash
ralph-sandbox-loop path/to/task.md 3
ralph-sandbox-loop --existing-sandbox r-dev path/to/task.md 3
```

Sandbox rules:

- `build-kiro-sandbox-template.sh` runs `sync-kit-skills.sh`, expands symlinked skills, and bakes this repo's generated Kiro config into `/home/agent/.kiro`.
- The template extends `docker/sandbox-templates:kiro-docker` and installs Node.js 24, pnpm, Playwright, RTK, and uv.
- `kits/kiro-sandbox/spec.yaml` is a `kind: mixin` kit that extends the built-in `kiro` agent.
- The kit allows network access, proxy-manages Exa and Figma credentials, and sets `PATH`/`PNPM_HOME`.
- `ralph-sandbox-loop` writes generated prompts under `~/.kiro/.ralph-sandbox-loop/`, runs `chat --no-interactive --trust-all-tools --agent ralph`, and stops when Ralph prints `<promise>NO MORE TASKS</promise>`.
- Kiro device-flow auth is stored inside the sandbox at `~/.local/share/kiro-cli/data.sqlite3` and persists until the sandbox is destroyed.

## Architecture

```text
user
  |
  v
code_supervisor
  |-- leaf agents: developer, reviewer, designer, explorer, simplifier,
  |   tester, debugger, planner, researcher
  |
  |-- council agents: councillor-a, councillor-b, councillor-c, council-master
  |
  `-- .plan/<task>/ artifacts for inter-agent handoff
```

Key rules:

- `generate-configs.sh` generates `agents/*.json` and `settings/mcp.json`.
- `sync-kit-skills.sh` copies local skills into the Kiro sandbox kit and expands symlinks into real directories.
- `build-kiro-sandbox-template.sh` builds a Kiro Docker Sandbox template with RTK, Git config, and generated `~/.kiro`.
- Agent prompts live in `agents/*.md`.
- Hook scripts live in `hooks/`.
- Skills live in `skills/*/SKILL.md`.
- `.plan/<task>/` is the coordination layer for delegated work.

## Agents

### Leaf Agents

| Agent | Role | Model | MCP |
|-------|------|-------|-----|
| `developer` | Code implementation | `claude-opus-4.7` | `local-fs` |
| `reviewer` | Code review and YAGNI enforcement | `claude-opus-4.7` | - |
| `designer` | Figma design extraction | `claude-opus-4.7` | `figma-developer-mcp` |
| `explorer` | Codebase and docs research | `claude-sonnet-4.6` | `context7`, `exa`, `github-grep` |
| `simplifier` | Code refinement | `claude-opus-4.7` | `git` |
| `tester` | Verification evidence and risk analysis | `claude-opus-4.7` | - |
| `debugger` | Root cause investigation | `claude-opus-4.7` | - |
| `planner` | Structured execution plans | `claude-opus-4.7` | - |
| `researcher` | Web and paper research | `claude-opus-4.7` | `exa` |
| `ralph` | Sandbox YOLO implementation loop | `claude-opus-4.8` | all MCP servers |

### Supervisor

| Agent | Role | Model | MCP |
|-------|------|-------|-----|
| `code_supervisor` | Delegates work and verifies `.plan` artifacts | `claude-opus-4.7` | `git`, `local-fs` |

### Council

| Agent | Role | Model |
|-------|------|-------|
| `councillor-a` | Independent read-only advisor | `claude-opus-4.7` |
| `councillor-b` | Independent read-only advisor | `glm-5` |
| `councillor-c` | Independent read-only advisor | `deepseek-3.2` |
| `council-master` | Synthesizes council consensus | `claude-opus-4.7` |

## Hooks

Runtime hooks are injected by `generate-configs.sh`; test files under `hooks/test-*` are not runtime hooks.

| Hook | Trigger | Scope | Purpose |
|------|---------|-------|---------|
| `shell/rtk-rewrite.js` | `preToolUse` | Shell-capable agents | Rewrites shell commands through RTK |
| `shell/rtk-rules.sh` | `agentSpawn` | Shell-capable agents | Adds RTK command guidance at startup |
| `shell/validate-local-rm.js` | `preToolUse` | `developer` | Blocks unsafe `rm` targets outside cwd |
| `caveman.sh` | `agentSpawn` | All agents | Injects terse response style |
| `locale.sh` | `agentSpawn` | All agents | Injects Traditional Chinese locale |
| `code_supervisor/phase-reminder.sh` | `userPromptSubmit` | `code_supervisor` | Enforces the delegation workflow |
| `cmux-notify.sh` | `stop` | `code_supervisor`, `ralph` | Sends cmux desktop notifications |
| `code_supervisor/validate-read-allowed-paths.js` | `preToolUse` | `code_supervisor` | Restricts supervisor reads |
| `code_supervisor/validate-supervisor-plan-write.js` | `preToolUse` | `code_supervisor` | Protects planner-owned plan files |
| `planner/validate-planner-plan-write.js` | `preToolUse` | `planner` | Restricts formal plan writes |
| `planner/open-task-markdown.js` | `postToolUse` | `planner` | Opens new task markdown in cmux |
| `plan_writers/validate-artifact-plan-write.js` | `preToolUse` | `.plan` writers | Restricts artifact writes to `.plan/` |
| `source_writing/validate-developer-plan.js` | `preToolUse` | Source-writing agents | Requires an active planner-ready task before writes |

## RTK

RTK is required for shell-capable agents. This setup has two layers:

1. `shell/rtk-rules.sh` tells agents to prefix shell commands with `rtk`.
2. `shell/rtk-rewrite.js` intercepts shell tool calls and rewrites missing prefixes.

The hook silently skips if RTK is unavailable or too old.

## Skills

Tracked local skills:

| Skill | Purpose |
|-------|---------|
| `cartography` | Generate repository codemaps |
| `cmux` | Manage cmux windows, workspaces, panes, and focus |
| `cmux-browser` | Browser automation through cmux |
| `cmux-debug-windows` | Manage cmux debug windows and snapshots |
| `cmux-markdown` | Open markdown in cmux with live reload |
| `council-session` | Multi-model consensus workflow |
| `debug-hypothesis` | Hypothesis-driven debugging |
| `get-code-context-exa` | Search code context with Exa |
| `supervisor-workflow` | Supervisor delegation workflow |
| `web-search-advanced-research-paper-exa` | Research paper search via Exa |

Some local skill directories may be symlinks into `~/.agents/skills`; they are intentionally separate from the tracked skill set above.

## MCP Servers

`generate-configs.sh` writes `settings/mcp.json` with these servers:

| Server | Transport | Purpose |
|--------|-----------|---------|
| `git` | `uvx mcp-server-git` | Git operations with isolated global config |
| `context7` | `npx -y @upstash/context7-mcp` | Library documentation lookup |
| `local-fs` | `node ~/.kiro/mcp/local-fs/server.mjs` | Constrained `rm` and `mkdir` helpers |
| `chrome-devtools` | `npx -y chrome-devtools-mcp@latest` | Browser debugging, disabled by default |
| `figma-developer-mcp` | `npx -y figma-developer-mcp --stdio` | Figma design extraction |
| `exa` | Remote MCP | Web search, fetch, and advanced search |
| `github-grep` | Remote MCP | GitHub code search |

## Config Pipeline

```text
agents/*.md
hooks/*
skills/*/SKILL.md
mcp/local-fs/server.mjs
        |
        v
generate-configs.sh
        |
        v
agents/*.json
settings/mcp.json
```

Generated config is runtime state. Edit the markdown prompts, hook scripts, skill files, or generator script instead.

## Plan Folder Protocol

`.plan/<task-name>/` is the file-based IPC layer between the supervisor and delegated agents.

| File | Owner | Purpose |
|------|-------|---------|
| `task.md` | `planner` | Full task requirements |
| `questions.md` | `planner` | Clarifying questions, or `NO_QUESTIONS` |
| `.planner-ready.json` | `planner` | Marker for a ready plan |
| `answers.md` | user / supervisor | User answers to planner questions |
| `exploration-brief.md` | `explorer` | Codebase findings |
| `design-spec.md` | `designer` | UI design specification |
| `dev-notes.md` | `developer` | Implementation notes |
| `test-notes.md` | `tester` | Verification evidence |
| `review.md` | `reviewer` | Review findings |
| `simplifier-notes.md` | `simplifier` | Simplification notes |
| `DEBUG.md` | `debugger` | Debug hypothesis trail |
| `feedback-investigation.md` | `debugger` | Feedback investigation summary |
| `assets/` | `designer` | Downloaded design assets |

## Design Patterns

1. Code generation over hand-edited JSON.
2. Runtime hook injection for behavior that should not live in prompts.
3. Least-privilege agent tool access.
4. File-based plan artifacts for traceable handoffs.
5. Parallel delegation for independent work.
6. Multi-model council review for high-stakes decisions.
