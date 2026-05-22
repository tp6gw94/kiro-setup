#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HOOK="$ROOT/hooks/code_supervisor/validate-read-allowed-paths.js"

tmpdir=$(mktemp -d /tmp/validate-read-allowed-paths.XXXXXX)
trap 'rm -rf "$tmpdir"' EXIT

test_home="$tmpdir/home"
kiro_home="$test_home/.kiro"
mkdir -p "$tmpdir/.plan/task" "$kiro_home/agents"

run_hook() {
  local payload="$1"
  (
    cd "$tmpdir"
    HOME="$test_home" KIRO_HOME="$kiro_home" printf '%s\n' "$payload" | HOME="$test_home" KIRO_HOME="$kiro_home" "$HOOK"
  )
}

assert_allows_plan_read() {
  run_hook '{"cwd":"'"$tmpdir"'","tool_input":{"operations":[{"mode":"Line","path":"'"$tmpdir"'/.plan/task/task.md"}]}}'
}

assert_allows_relative_plan_read() {
  run_hook '{"cwd":"'"$tmpdir"'","tool_input":{"operations":[{"mode":"Line","path":".plan/task/task.md"}]}}'
}

assert_allows_kiro_home_read() {
  run_hook '{"cwd":"'"$tmpdir"'","tool_input":{"operations":[{"mode":"Line","path":"'"$kiro_home"'/agents/code_supervisor.md"}]}}'
}

assert_allows_tilde_kiro_home_read() {
  run_hook '{"cwd":"'"$tmpdir"'","tool_input":{"operations":[{"mode":"Line","path":"~/.kiro/agents/code_supervisor.md"}]}}'
}

assert_allows_var_folders_read() {
  run_hook '{"cwd":"'"$tmpdir"'","tool_input":{"operations":[{"mode":"Line","path":"/var/folders/example"}]}}'
}

assert_blocks_outside_read() {
  local err="$tmpdir/read.err"

  if run_hook '{"cwd":"'"$tmpdir"'","tool_input":{"operations":[{"mode":"Line","path":"/etc/passwd"}]}}' 2>"$err"; then
    echo "expected outside read to block" >&2
    exit 1
  fi

  if ! grep -q "code_supervisor cannot read" "$err"; then
    echo "expected read block error message" >&2
    cat "$err" >&2
    exit 1
  fi
}

assert_blocks_mixed_operations() {
  local err="$tmpdir/mixed.err"

  if run_hook '{"cwd":"'"$tmpdir"'","tool_input":{"operations":[{"mode":"Line","path":"'"$tmpdir"'/.plan/task/task.md"},{"mode":"Line","path":"/etc/hosts"}]}}' 2>"$err"; then
    echo "expected mixed allowed/disallowed read to block" >&2
    exit 1
  fi
}

assert_blocks_unknown_shape() {
  local err="$tmpdir/unknown.err"

  if run_hook '{"cwd":"'"$tmpdir"'","tool_input":{"unexpected":true}}' 2>"$err"; then
    echo "expected unknown read input shape to block" >&2
    exit 1
  fi

  if ! grep -q "Could not determine read path" "$err"; then
    echo "expected unknown shape error message" >&2
    cat "$err" >&2
    exit 1
  fi
}

assert_allows_plan_read
assert_allows_relative_plan_read
assert_allows_kiro_home_read
assert_allows_tilde_kiro_home_read
assert_allows_var_folders_read
assert_blocks_outside_read
assert_blocks_mixed_operations
assert_blocks_unknown_shape

echo "validate-read-allowed-paths tests passed"
