#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HOOK="$ROOT/hooks/planner/open-task-markdown.js"
NODE_BIN=$(command -v node)

tmpdir=$(mktemp -d)
mockbin="$tmpdir/bin"
log="$tmpdir/cmux.log"
state="$tmpdir/state"
mkdir -p "$mockbin" "$state"
trap 'rm -rf "$tmpdir"' EXIT

cat >"$mockbin/cmux" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [ "${CMUX_PING_FAIL:-0}" = "1" ] && [ "${1:-}" = "ping" ]; then
  exit 1
fi
printf '%s\n' "$*" >>"$CMUX_TEST_LOG"
MOCK
chmod +x "$mockbin/cmux"

run_hook() {
  local payload="$1"
  (
    cd "$tmpdir"
    printf '%s\n' "$payload" | env PATH="$mockbin:$PATH" CMUX_TEST_LOG="$log" KIRO_TASK_MARKDOWN_STATE_DIR="$state" "$HOOK"
  )
}

assert_opens_task_once() {
  mkdir -p "$tmpdir/.plan/demo"
  printf '# Task\n' >"$tmpdir/.plan/demo/task.md"
  local real_tmpdir
  real_tmpdir=$(cd "$tmpdir" && pwd -P)

  run_hook '{"hook_event_name":"postToolUse","session_id":"session-1","tool_name":"write","tool_input":{"path":".plan/demo/task.md"},"tool_response":{"success":true}}'
  grep -q "^ping$" "$log" || { cat "$log" >&2; exit 1; }
  grep -q "^markdown open $real_tmpdir/.plan/demo/task.md$" "$log" || { cat "$log" >&2; exit 1; }

  : >"$log"
  run_hook '{"hook_event_name":"postToolUse","session_id":"session-1","tool_name":"write","tool_input":{"path":".plan/demo/task.md"},"tool_response":{"success":true}}'
  if [ -s "$log" ]; then
    echo "expected repeated task.md write to skip cmux" >&2
    cat "$log" >&2
    exit 1
  fi
}

assert_skips_non_task_artifacts() {
  : >"$log"
  run_hook '{"hook_event_name":"postToolUse","session_id":"session-2","tool_name":"write","tool_input":{"path":".plan/demo/questions.md"},"tool_response":{"success":true}}'
  run_hook '{"hook_event_name":"postToolUse","session_id":"session-2","tool_name":"write","tool_input":{"path":".plan/demo/.planner-ready.json"},"tool_response":{"success":true}}'
  run_hook '{"hook_event_name":"postToolUse","session_id":"session-2","tool_name":"write","tool_input":{"path":"task.md"},"tool_response":{"success":true}}'
  if [ -s "$log" ]; then
    echo "expected non-task artifacts to skip cmux" >&2
    cat "$log" >&2
    exit 1
  fi
}

assert_skips_failed_write() {
  : >"$log"
  run_hook '{"hook_event_name":"postToolUse","session_id":"session-3","tool_name":"write","tool_input":{"path":".plan/demo/task.md"},"tool_response":{"success":false}}'
  if [ -s "$log" ]; then
    echo "expected failed write to skip cmux" >&2
    cat "$log" >&2
    exit 1
  fi
}

assert_skips_without_cmux() {
  (
    cd "$tmpdir"
    printf '%s\n' '{"hook_event_name":"postToolUse","session_id":"session-4","tool_name":"write","tool_input":{"path":".plan/demo/task.md"},"tool_response":{"success":true}}' |
      env PATH="/usr/bin:/bin" KIRO_TASK_MARKDOWN_STATE_DIR="$state" "$NODE_BIN" "$HOOK"
  )
}

assert_skips_when_cmux_not_running() {
  : >"$log"
  (
    cd "$tmpdir"
    printf '%s\n' '{"hook_event_name":"postToolUse","session_id":"session-5","tool_name":"write","tool_input":{"path":".plan/demo/task.md"},"tool_response":{"success":true}}' |
      env PATH="$mockbin:$PATH" CMUX_TEST_LOG="$log" KIRO_TASK_MARKDOWN_STATE_DIR="$state" CMUX_PING_FAIL=1 "$HOOK"
  )
  if [ -s "$log" ]; then
    echo "expected cmux ping failure to skip markdown open" >&2
    cat "$log" >&2
    exit 1
  fi
}

assert_opens_task_once
assert_skips_non_task_artifacts
assert_skips_failed_write
assert_skips_without_cmux
assert_skips_when_cmux_not_running

echo "open-task-markdown tests passed"
