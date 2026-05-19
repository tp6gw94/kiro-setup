#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HOOK="$ROOT/hooks/code_supervisor/validate-supervisor-plan-write.js"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

run_hook() {
  local payload="$1"
  (
    cd "$tmpdir"
    printf '%s\n' "$payload" | "$HOOK"
  )
}

make_ready_plan() {
  local task="$1"
  mkdir -p "$tmpdir/.plan/$task"
  printf '# Task\n' > "$tmpdir/.plan/$task/task.md"
  printf 'NO_QUESTIONS\n' > "$tmpdir/.plan/$task/questions.md"
  printf '{"ready":true}\n' > "$tmpdir/.plan/$task/.planner-ready.json"
}

assert_allows_answers_write() {
  mkdir -p "$tmpdir/.plan/task"
  run_hook '{"tool_input":{"path":".plan/task/answers.md","content":"answer"}}'
}

assert_blocks_task_write() {
  local err="$tmpdir/task.err"
  mkdir -p "$tmpdir/.plan/task"

  if run_hook '{"tool_input":{"path":".plan/task/task.md","content":"# Task"}}' 2>"$err"; then
    echo "expected supervisor task.md write to block" >&2
    exit 1
  fi

  grep -q "planner-owned" "$err" || { cat "$err" >&2; exit 1; }
}

assert_blocks_questions_write() {
  local err="$tmpdir/questions.err"
  mkdir -p "$tmpdir/.plan/task"

  if run_hook '{"tool_input":{"path":".plan/task/questions.md","content":"NO_QUESTIONS"}}' 2>"$err"; then
    echo "expected supervisor questions.md write to block" >&2
    exit 1
  fi

  grep -q "planner-owned" "$err" || { cat "$err" >&2; exit 1; }
}

assert_blocks_planner_marker_write() {
  local err="$tmpdir/marker.err"
  mkdir -p "$tmpdir/.plan/task"

  if run_hook '{"tool_input":{"path":".plan/task/.planner-ready.json","content":"{}"}}' 2>"$err"; then
    echo "expected supervisor planner marker write to block" >&2
    exit 1
  fi

  grep -q "planner-owned" "$err" || { cat "$err" >&2; exit 1; }
}

assert_blocks_active_plan_without_marker() {
  local err="$tmpdir/no-marker.err"
  mkdir -p "$tmpdir/.plan/task"
  printf '# Task\n' > "$tmpdir/.plan/task/task.md"
  printf 'NO_QUESTIONS\n' > "$tmpdir/.plan/task/questions.md"

  if run_hook '{"tool_input":{"path":".plan/.active-developer-plan","content":"'"$tmpdir"'/.plan/task\n"}}' 2>"$err"; then
    echo "expected active plan without planner marker to block" >&2
    exit 1
  fi

  grep -q ".planner-ready.json" "$err" || { cat "$err" >&2; exit 1; }
}

assert_blocks_active_plan_with_questions() {
  local err="$tmpdir/questions-open.err"
  mkdir -p "$tmpdir/.plan/task"
  printf '# Task\n' > "$tmpdir/.plan/task/task.md"
  printf '# Questions\n' > "$tmpdir/.plan/task/questions.md"
  printf '{"ready":true}\n' > "$tmpdir/.plan/task/.planner-ready.json"

  if run_hook '{"tool_input":{"path":".plan/.active-developer-plan","content":"'"$tmpdir"'/.plan/task\n"}}' 2>"$err"; then
    echo "expected active plan with open questions to block" >&2
    exit 1
  fi

  grep -q "NO_QUESTIONS" "$err" || { cat "$err" >&2; exit 1; }
}

assert_allows_ready_active_plan() {
  make_ready_plan "task"
  run_hook '{"tool_input":{"path":".plan/.active-developer-plan","content":"'"$tmpdir"'/.plan/task\n"}}'
}

assert_allows_relative_ready_active_plan() {
  make_ready_plan "relative-task"
  run_hook '{"tool_input":{"path":".plan/.active-developer-plan","content":".plan/relative-task\n"}}'
}

assert_allows_legacy_active_marker_rewrite() {
  make_ready_plan "task"
  printf '%s\n' "$tmpdir/.plan/task" > "$tmpdir/.plan/.active-developer-plan"
  run_hook '{"tool_input":{"path":".plan/.active-developer-plan"}}'
}

assert_allows_answers_write
assert_blocks_task_write
assert_blocks_questions_write
assert_blocks_planner_marker_write
assert_blocks_active_plan_without_marker
assert_blocks_active_plan_with_questions
assert_allows_ready_active_plan
assert_allows_relative_ready_active_plan
assert_allows_legacy_active_marker_rewrite

echo "validate-supervisor-plan-write tests passed"
