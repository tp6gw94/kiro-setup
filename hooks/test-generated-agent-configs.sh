#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
AGENTS_DIR="$HOME/.kiro/agents"
PLAN_HOOK="$HOME/.kiro/hooks/validate-write-plan-folder.sh"
ACTIVE_PLAN_HOOK="$HOME/.kiro/hooks/validate-developer-plan.sh"
READ_HOOK="$HOME/.kiro/hooks/validate-read-allowed-paths.sh"
PHASE_HOOK="$HOME/.kiro/hooks/phase-reminder.sh"

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

  if ! jq -e --arg hook "$PLAN_HOOK" \
    '.toolsSettings.write.allowedPaths == ["./.plan"] and any(.hooks.preToolUse[]?; .command == $hook and .matcher == "write")' \
    "$file" >/dev/null; then
    echo "$name must write only .plan and use the plan-folder write hook" >&2
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

for name in code_supervisor reviewer designer explorer debugger planner; do
  require_plan_only_writer "$name"
done

for name in developer tester simplifier; do
  require_active_plan_writer "$name"
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
