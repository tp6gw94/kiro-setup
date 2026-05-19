#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
AGENTS_DIR="$HOME/.kiro/agents"
ARTIFACT_PLAN_HOOK="$HOME/.kiro/hooks/plan_writers/validate-artifact-plan-write.js"
PLANNER_PLAN_HOOK="$HOME/.kiro/hooks/planner/validate-planner-plan-write.js"
SUPERVISOR_PLAN_HOOK="$HOME/.kiro/hooks/code_supervisor/validate-supervisor-plan-write.js"
ACTIVE_PLAN_HOOK="$HOME/.kiro/hooks/source_writing/validate-developer-plan.js"
READ_HOOK="$HOME/.kiro/hooks/code_supervisor/validate-read-allowed-paths.js"
PHASE_HOOK="$HOME/.kiro/hooks/code_supervisor/phase-reminder.sh"
RTK_HOOK="$HOME/.kiro/hooks/shell/rtk-rewrite.js"

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

if ! jq -e --arg hook "$SUPERVISOR_PLAN_HOOK" \
  '.toolsSettings.write.allowedPaths == ["./.plan"] and any(.hooks.preToolUse[]?; .command == $hook and .matcher == "write")' \
  "$AGENTS_DIR/code_supervisor.json" >/dev/null; then
  echo "code_supervisor must write .plan only through the supervisor plan hook" >&2
  jq '{name, tools, allowedTools, toolsSettings, hooks}' "$AGENTS_DIR/code_supervisor.json" >&2
  exit 1
fi

if ! jq -e \
  '(.tools | index("shell") | not) and (.allowedTools | index("shell") | not) and (.toolsSettings | has("shell") | not)' \
  "$AGENTS_DIR/code_supervisor.json" >/dev/null; then
  echo "code_supervisor must not expose shell; verification belongs to tester/reviewer artifacts" >&2
  jq '{name, tools, allowedTools, toolsSettings, hooks}' "$AGENTS_DIR/code_supervisor.json" >&2
  exit 1
fi

for name in developer tester simplifier; do
  require_active_plan_writer "$name"
done

for name in developer reviewer designer explorer simplifier tester debugger; do
  require_jq "$AGENTS_DIR/$name.json" \
    'any(.hooks.preToolUse[]?; .command == "'"$RTK_HOOK"'" and .matcher == "shell")' \
    "$name must use the Node.js RTK rewrite hook"
done

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
  '.toolsSettings.read.allowedPaths == ["./.plan", "/var/folders", $home] and any(.hooks.preToolUse[]?; .command == $hook and .matcher == "read")' \
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
