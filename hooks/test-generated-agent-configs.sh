#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
AGENTS_DIR="$HOME/.kiro/agents"
ARTIFACT_PLAN_HOOK="$HOME/.kiro/hooks/plan_writers/validate-artifact-plan-write.js"
PLANNER_PLAN_HOOK="$HOME/.kiro/hooks/planner/validate-planner-plan-write.js"
PLANNER_OPEN_TASK_MARKDOWN_HOOK="$HOME/.kiro/hooks/planner/open-task-markdown.js"
SUPERVISOR_PLAN_HOOK="$HOME/.kiro/hooks/code_supervisor/validate-supervisor-plan-write.js"
ACTIVE_PLAN_HOOK="$HOME/.kiro/hooks/source_writing/validate-developer-plan.js"
READ_HOOK="$HOME/.kiro/hooks/code_supervisor/validate-read-allowed-paths.js"
PHASE_HOOK="$HOME/.kiro/hooks/code_supervisor/phase-reminder.sh"
RTK_HOOK="$HOME/.kiro/hooks/shell/rtk-rewrite.js"
LOCAL_RM_HOOK="$HOME/.kiro/hooks/shell/validate-local-rm.js"
LOCAL_FS_SERVER="$HOME/.kiro/mcp/local-fs/server.mjs"
DISALLOWED_AGENTS_SKILLS_URI="skill://$HOME/.agents/skills/**/SKILL.md"
DISALLOWED_AGENTS_SKILLS_DIR="$HOME/.agents/skills"
PROMPT_DIR="$ROOT/agents"

cd "$ROOT"
EXA_API_KEY=dummy bash "$ROOT/generate-configs.sh" >/tmp/generated-agent-configs.out

require_jq() {
  local file="$1"
  local filter="$2"
  local message="$3"

  if ! jq -e "$filter" "$file" >/dev/null; then
    echo "$message" >&2
    echo "File: $file" >&2
    jq '{name, tools, allowedTools, toolsSettings, hooks}' "$file" >&2
    exit 1
  fi
}

require_no_file() {
  local file="$1"
  local message="$2"

  if [[ -e "$file" ]]; then
    echo "$message" >&2
    exit 1
  fi
}

require_prompt_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if ! grep -q "$pattern" "$file"; then
    echo "$message" >&2
    echo "File: $file" >&2
    exit 1
  fi
}

require_prompt_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -qi "$pattern" "$file"; then
    echo "$message" >&2
    echo "File: $file" >&2
    grep -ni "$pattern" "$file" >&2
    exit 1
  fi
}

require_plan_only_writer() {
  local name="$1"
  local file="$AGENTS_DIR/$name.json"

  if ! jq -e --arg hook "$ARTIFACT_PLAN_HOOK" \
    '.toolsSettings.write.allowedPaths == ["./.plan"] and any(.hooks.preToolUse[]?; .command == $hook and .matcher == "write")' \
    "$file" >/dev/null; then
    echo "$name must write only .plan and use the artifact plan hook" >&2
    echo "File: $file" >&2
    jq '{name, tools, allowedTools, toolsSettings, hooks}' "$file" >&2
    exit 1
  fi
}

require_active_plan_writer() {
  local name="$1"
  local file="$AGENTS_DIR/$name.json"

  if ! jq -e --arg hook "$ACTIVE_PLAN_HOOK" \
    '.toolsSettings.write.allowedPaths == ["./"] and any(.hooks.preToolUse[]?; .command == $hook and .matcher == "write")' \
    "$file" >/dev/null; then
    echo "$name must write workspace files only behind the active-plan hook" >&2
    echo "File: $file" >&2
    jq '{name, tools, allowedTools, toolsSettings, hooks}' "$file" >&2
    exit 1
  fi
}

for name in reviewer designer explorer debugger; do
  require_plan_only_writer "$name"
done

if ! jq -e --arg hook "$PLANNER_PLAN_HOOK" \
  '.toolsSettings.write.allowedPaths == ["./.plan"] and any(.hooks.preToolUse[]?; .command == $hook and .matcher == "write")' \
  "$AGENTS_DIR/planner.json" >/dev/null; then
  echo "planner must write .plan only through the planner plan hook" >&2
  jq '{name, tools, allowedTools, toolsSettings, hooks}' "$AGENTS_DIR/planner.json" >&2
  exit 1
fi

if ! jq -e --arg hook "$PLANNER_OPEN_TASK_MARKDOWN_HOOK" \
  'any(.hooks.postToolUse[]?; .command == $hook and .matcher == "write")' \
  "$AGENTS_DIR/planner.json" >/dev/null; then
  echo "planner must open task.md with cmux markdown after successful writes when cmux is available" >&2
  jq '{name, tools, allowedTools, toolsSettings, hooks}' "$AGENTS_DIR/planner.json" >&2
  exit 1
fi

if ! jq -e --arg hook "$SUPERVISOR_PLAN_HOOK" \
  '.toolsSettings.write.allowedPaths == ["./.plan"] and any(.hooks.preToolUse[]?; .command == $hook and .matcher == "write")' \
  "$AGENTS_DIR/code_supervisor.json" >/dev/null; then
  echo "code_supervisor must write .plan only through the supervisor plan hook" >&2
  jq '{name, tools, allowedTools, toolsSettings, hooks}' "$AGENTS_DIR/code_supervisor.json" >&2
  exit 1
fi

if ! jq -e \
  '(.tools | index("shell")) and (.allowedTools | index("shell") | not) and .toolsSettings.shell.allowedCommands == ["rkt cmux .*"] and .toolsSettings.shell.denyByDefault == true' \
  "$AGENTS_DIR/code_supervisor.json" >/dev/null; then
  echo "code_supervisor must keep the cmux-only shell tool gated out of allowedTools" >&2
  jq '{name, tools, allowedTools, toolsSettings, hooks}' "$AGENTS_DIR/code_supervisor.json" >&2
  exit 1
fi

for name in developer tester simplifier; do
  require_active_plan_writer "$name"
done

for name in developer reviewer explorer simplifier tester debugger planner code_supervisor; do
  require_jq "$AGENTS_DIR/$name.json" \
    'all(.resources[]?; . != "'"$DISALLOWED_AGENTS_SKILLS_URI"'")' \
    "$name must not include ~/.agents/skills as a skill resource"
done

for name in developer reviewer simplifier tester debugger planner code_supervisor; do
  require_jq "$AGENTS_DIR/$name.json" \
    'all(.toolsSettings.read.allowedPaths[]?; . != "'"$DISALLOWED_AGENTS_SKILLS_DIR"'")' \
    "$name must not include ~/.agents/skills as a readable skill root"
done

for name in developer reviewer designer explorer simplifier tester debugger; do
  require_jq "$AGENTS_DIR/$name.json" \
    'any(.hooks.preToolUse[]?; .command == "'"$RTK_HOOK"'" and .matcher == "shell")' \
    "$name must use the Node.js RTK rewrite hook"
done

require_jq "$AGENTS_DIR/developer.json" \
  'any(.hooks.preToolUse[]?; .command == "'"$LOCAL_RM_HOOK"'" and .matcher == "shell")' \
  "developer must use the local rm validation hook"

require_jq "$AGENTS_DIR/developer.json" \
  '(.tools | index("@local-fs")) and (.allowedTools | index("@local-fs"))' \
  "developer must expose the local-fs MCP tools"

require_jq "$AGENTS_DIR/developer.json" \
  '.mcpServers."local-fs".type == "stdio" and .mcpServers."local-fs".command == "node" and .mcpServers."local-fs".args == ["'"$LOCAL_FS_SERVER"'"]' \
  "developer must configure the local-fs MCP server"

require_jq "$AGENTS_DIR/developer.json" \
  'all(.toolsSettings.shell.allowedCommands[]?; . != "rtk rm .*")' \
  "developer shell allowlist must route deletion through local-fs instead of rtk rm"

require_jq "$AGENTS_DIR/code_supervisor.json" \
  '(.tools | index("@local-fs")) and (.allowedTools | index("@local-fs"))' \
  "code_supervisor must expose the local-fs MCP tools"

require_jq "$AGENTS_DIR/code_supervisor.json" \
  '.mcpServers."local-fs".type == "stdio" and .mcpServers."local-fs".command == "node" and .mcpServers."local-fs".args == ["'"$LOCAL_FS_SERVER"'"]' \
  "code_supervisor must configure the local-fs MCP server"

for name in reviewer designer explorer simplifier tester debugger; do
  require_jq "$AGENTS_DIR/$name.json" \
    'all(.hooks.preToolUse[]?; .command != "'"$LOCAL_RM_HOOK"'")' \
    "$name must not use the developer-only local rm validation hook"
done

require_jq "$AGENTS_DIR/reviewer.json" \
  '(.toolsSettings.shell.allowedCommands | any(. == "rtk agent-browser(?:[[:space:]].*)?")) and (.toolsSettings.shell.allowedCommands | any(. == "rtk npx[[:space:]]+agent-browser(?:[[:space:]].*)?")) and (.toolsSettings.shell.allowedCommands | all(test("playwright-cli") | not))' \
  "reviewer shell allowlist must use agent-browser instead of playwright-cli"

for name in code_supervisor planner tester debugger reviewer; do
  prompt="$PROMPT_DIR/$name.md"
  require_prompt_contains "$prompt" "agent-browser" "$name prompt must route browser automation through agent-browser"
  require_prompt_contains "$prompt" "agent-browser skill" "$name prompt must tell agents to read the agent-browser skill before use"
  require_prompt_not_contains "$prompt" "playwright-cli\\|Playwright" "$name prompt must not mention Playwright after agent-browser migration"
done

if [[ ! -f "$ROOT/skills/debug-hypothesis/SKILL.md" ]]; then
  echo "debug-hypothesis skill must exist" >&2
  exit 1
fi

require_prompt_contains "$PROMPT_DIR/debugger.md" "debug-hypothesis" "debugger must use the debug-hypothesis skill for non-trivial bugs"
require_prompt_contains "$PROMPT_DIR/debugger.md" "DEBUG.md" "debugger must write DEBUG.md for hypothesis-driven investigations"
require_prompt_contains "$PROMPT_DIR/debugger.md" "feedback-investigation.md" "debugger must write feedback-investigation.md for planner-facing investigation output"

require_prompt_contains "$PROMPT_DIR/code_supervisor.md" "debug-hypothesis" "code_supervisor must delegate non-trivial bug investigations with debug-hypothesis"
require_prompt_contains "$PROMPT_DIR/code_supervisor.md" "DEBUG.md" "code_supervisor must expect DEBUG.md from debugger"
require_prompt_contains "$ROOT/skills/supervisor-workflow/SKILL.md" "debug-hypothesis" "supervisor workflow skill must require debug-hypothesis for non-trivial bugs"
require_prompt_contains "$ROOT/skills/supervisor-workflow/SKILL.md" "DEBUG.md" "supervisor workflow skill must expect DEBUG.md from debugger"

require_no_file "$AGENTS_DIR/librarian.json" "librarian.json should not be generated after merging librarian into explorer"

require_jq "$AGENTS_DIR/code_supervisor.json" \
  '(.toolsSettings.subagent.availableAgents | index("librarian") | not) and (.toolsSettings.subagent.trustedAgents | index("librarian") | not)' \
  "code_supervisor must not expose librarian as a subagent"

if ! jq -e --arg hook "$PHASE_HOOK" \
  'any(.hooks.userPromptSubmit[]?; .command == $hook)' \
  "$AGENTS_DIR/code_supervisor.json" >/dev/null; then
  echo "code_supervisor must inject the phase reminder on every user prompt" >&2
  jq '{name, hooks}' "$AGENTS_DIR/code_supervisor.json" >&2
  exit 1
fi

if ! jq -e --arg hook "$READ_HOOK" --arg home "$HOME/.kiro" \
  '.toolsSettings.read.allowedPaths == ["./.plan", "/var/folders", "/private/var/folders", $home] and any(.hooks.preToolUse[]?; .command == $hook and .matcher == "read")' \
  "$AGENTS_DIR/code_supervisor.json" >/dev/null; then
  echo "code_supervisor must restrict read roots and use the read-path hook" >&2
  jq '{name, toolsSettings, hooks}' "$AGENTS_DIR/code_supervisor.json" >&2
  exit 1
fi

for name in councillor-a councillor-b councillor-c council-master; do
  require_jq "$AGENTS_DIR/$name.json" \
    '.tools == ["read", "grep", "glob"] and .allowedTools == ["read", "grep", "glob"] and (.toolsSettings | has("write") | not) and (.toolsSettings | has("shell") | not) and (.toolsSettings | has("execute_bash") | not)' \
    "$name must be read-only without write or shell tooling"
done

echo "generated agent config tests passed"
