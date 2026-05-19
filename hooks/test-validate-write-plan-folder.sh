#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HOOK="$ROOT/hooks/plan_writers/validate-artifact-plan-write.js"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

run_hook() {
  local payload="$1"
  (
    cd "$tmpdir"
    printf '%s\n' "$payload" | "$HOOK"
  )
}

assert_allows_relative_plan_write() {
  mkdir -p "$tmpdir/.plan/task"
  run_hook '{"tool_input":{"path":".plan/task/review.md"}}'
}

assert_allows_absolute_plan_write() {
  mkdir -p "$tmpdir/.plan/task"
  run_hook '{"tool_input":{"path":"'"$tmpdir"'/.plan/task/review.md"}}'
}

assert_blocks_task_write() {
  local err="$tmpdir/task.err"
  mkdir -p "$tmpdir/.plan/task"

  if run_hook '{"tool_input":{"path":".plan/task/task.md"}}' 2>"$err"; then
    echo "expected artifact writer task.md write to block" >&2
    exit 1
  fi

  if ! grep -q "planner-owned" "$err"; then
    echo "expected planner-owned error message" >&2
    cat "$err" >&2
    exit 1
  fi
}

assert_blocks_questions_write() {
  local err="$tmpdir/questions.err"
  mkdir -p "$tmpdir/.plan/task"

  if run_hook '{"tool_input":{"path":".plan/task/questions.md"}}' 2>"$err"; then
    echo "expected artifact writer questions.md write to block" >&2
    exit 1
  fi

  if ! grep -q "planner-owned" "$err"; then
    echo "expected planner-owned error message" >&2
    cat "$err" >&2
    exit 1
  fi
}

assert_blocks_planner_marker_write() {
  local err="$tmpdir/marker.err"
  mkdir -p "$tmpdir/.plan/task"

  if run_hook '{"tool_input":{"path":".plan/task/.planner-ready.json"}}' 2>"$err"; then
    echo "expected artifact writer planner marker write to block" >&2
    exit 1
  fi

  if ! grep -q "planner-owned" "$err"; then
    echo "expected planner-owned error message" >&2
    cat "$err" >&2
    exit 1
  fi
}

assert_blocks_outside_plan_write() {
  local err="$tmpdir/write.err"

  if run_hook '{"tool_input":{"path":"src/app.ts"}}' 2>"$err"; then
    echo "expected outside write to block" >&2
    exit 1
  fi

  if ! grep -q "cannot write" "$err"; then
    echo "expected write block error message" >&2
    cat "$err" >&2
    exit 1
  fi
}

assert_blocks_unknown_shape() {
  local err="$tmpdir/unknown.err"

  if run_hook '{"tool_input":{"unexpected":true}}' 2>"$err"; then
    echo "expected unknown write input shape to block" >&2
    exit 1
  fi

  if ! grep -q "unknown path" "$err"; then
    echo "expected unknown path error message" >&2
    cat "$err" >&2
    exit 1
  fi
}

assert_allows_relative_plan_write
assert_allows_absolute_plan_write
assert_blocks_task_write
assert_blocks_questions_write
assert_blocks_planner_marker_write
assert_blocks_outside_plan_write
assert_blocks_unknown_shape

echo "validate-artifact-plan-write tests passed"
