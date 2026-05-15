#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HOOK="$ROOT/hooks/validate-developer-plan.sh"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
out="$tmpdir/plan-gate.out"
err="$tmpdir/plan-gate.err"

run_hook() {
  (
    cd "$tmpdir"
    printf '%s\n' '{"tool_input":{"path":"src/app.ts"}}' | bash "$HOOK"
  )
}

assert_blocks_without_active_plan() {
  mkdir -p "$tmpdir/.plan"

  if run_hook >"$out" 2>"$err"; then
    echo "expected missing active plan marker to block" >&2
    exit 1
  fi

  if ! grep -q "requires an approved .plan/<task-name>/task.md" "$err"; then
    echo "expected missing marker error message" >&2
    cat "$err" >&2
    exit 1
  fi
}

assert_blocks_missing_task_file() {
  mkdir -p "$tmpdir/.plan/missing-task"
  printf '%s\n' "$tmpdir/.plan/missing-task" > "$tmpdir/.plan/.active-developer-plan"

  if run_hook >"$out" 2>"$err"; then
    echo "expected missing task.md to block" >&2
    exit 1
  fi

  if ! grep -q "task.md was not found" "$err"; then
    echo "expected missing task.md error message" >&2
    cat "$err" >&2
    exit 1
  fi
}

assert_allows_active_plan_with_task_file() {
  mkdir -p "$tmpdir/.plan/valid-task"
  printf '# Task\n' > "$tmpdir/.plan/valid-task/task.md"
  printf '%s\n' "$tmpdir/.plan/valid-task" > "$tmpdir/.plan/.active-developer-plan"

  run_hook >"$out" 2>"$err"
}

assert_rejects_plan_outside_plan_root() {
  mkdir -p "$tmpdir/not-plan"
  printf '# Task\n' > "$tmpdir/not-plan/task.md"
  printf '%s\n' "$tmpdir/not-plan" > "$tmpdir/.plan/.active-developer-plan"

  if run_hook >"$out" 2>"$err"; then
    echo "expected plan outside .plan to block" >&2
    exit 1
  fi

  if ! grep -q "must point inside .plan" "$err"; then
    echo "expected outside .plan error message" >&2
    cat "$err" >&2
    exit 1
  fi
}

assert_blocks_without_active_plan
assert_blocks_missing_task_file
assert_allows_active_plan_with_task_file
assert_rejects_plan_outside_plan_root

echo "validate-developer-plan tests passed"
