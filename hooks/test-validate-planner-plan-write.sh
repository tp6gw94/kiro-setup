#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HOOK="$ROOT/hooks/planner/validate-planner-plan-write.js"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

run_hook() {
  local payload="$1"
  (
    cd "$tmpdir"
    printf '%s\n' "$payload" | "$HOOK"
  )
}

assert_allows_task_write() {
  mkdir -p "$tmpdir/.plan/task"
  run_hook '{"tool_input":{"path":".plan/task/task.md","content":"# Task"}}'
}

assert_allows_questions_write() {
  mkdir -p "$tmpdir/.plan/task"
  run_hook '{"tool_input":{"path":".plan/task/questions.md","content":"NO_QUESTIONS"}}'
}

assert_allows_planner_marker_write() {
  mkdir -p "$tmpdir/.plan/task"
  run_hook '{"tool_input":{"path":".plan/task/.planner-ready.json","content":"{\"ready\":true}"}}'
}

assert_blocks_outside_plan_write() {
  local err="$tmpdir/outside.err"

  if run_hook '{"tool_input":{"path":"src/app.ts","content":"x"}}' 2>"$err"; then
    echo "expected outside write to block" >&2
    exit 1
  fi

  grep -q "cannot write" "$err" || { cat "$err" >&2; exit 1; }
}

assert_allows_task_write
assert_allows_questions_write
assert_allows_planner_marker_write
assert_blocks_outside_plan_write

echo "validate-planner-plan-write tests passed"
