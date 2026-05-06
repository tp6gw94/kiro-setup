#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT_DIR/bin/codex-kiro"

fail() {
  echo "not ok - $1" >&2
  exit 1
}

assert_file_contains() {
  local file="$1"
  local expected="$2"
  grep -Fq -- "$expected" "$file" || fail "expected $file to contain: $expected"
}

assert_json_value() {
  local file="$1"
  local filter="$2"
  local expected="$3"
  local actual
  actual="$(jq -r "$filter" "$file")"
  [[ "$actual" == "$expected" ]] || fail "expected $filter in $file to be '$expected', got '$actual'"
}

make_fixture() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/dispatch.json" <<'JSON'
{
  "version": 1,
  "task": "adapter-test",
  "mode": "non_interactive",
  "waves": [
    {
      "id": "wave-1",
      "jobs": [
        {
          "id": "explore",
          "agent": "explorer",
          "prompt": "Read context.md and write a short exploration brief.",
          "output": "exploration-brief.md"
        }
      ]
    },
    {
      "id": "wave-2",
      "jobs": [
        {
          "id": "review",
          "agent": "reviewer",
          "prompt": "Review the implementation notes.",
          "output": "review.md",
          "trustTools": "fs_read,fs_write"
        }
      ]
    }
  ]
}
JSON
}

install_fake_kiro() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/kiro-cli" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "$KIRO_FAKE_CALLS"
agent=""
prompt="${@: -1}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)
      agent="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
echo "agent=$agent"
echo "prompt=$prompt"
echo "fake stderr for $agent" >&2
SH
  chmod +x "$bin_dir/kiro-cli"
}

test_dispatch_writes_outputs_and_status() {
  local tmp
  tmp="$(mktemp -d)"
  local fake_bin="$tmp/bin"
  local plan_dir="$tmp/plan"
  make_fixture "$plan_dir"
  install_fake_kiro "$fake_bin"
  export KIRO_FAKE_CALLS="$tmp/calls.log"

  PATH="$fake_bin:$PATH" "$BIN" dispatch "$plan_dir"

  assert_file_contains "$plan_dir/exploration-brief.md" "agent=explorer"
  assert_file_contains "$plan_dir/review.md" "agent=reviewer"
  assert_file_contains "$plan_dir/kiro/logs/explore.stderr.log" "fake stderr for explorer"
  assert_json_value "$plan_dir/kiro/status.json" '.jobs.explore.status' "done"
  assert_json_value "$plan_dir/kiro/status.json" '.jobs.review.agent' "reviewer"
  assert_file_contains "$tmp/calls.log" "chat --no-interactive --agent explorer"
  assert_file_contains "$tmp/calls.log" "--trust-tools fs_read,fs_write"
}

test_status_and_collect_read_plan_outputs() {
  local tmp
  tmp="$(mktemp -d)"
  local fake_bin="$tmp/bin"
  local plan_dir="$tmp/plan"
  make_fixture "$plan_dir"
  install_fake_kiro "$fake_bin"
  export KIRO_FAKE_CALLS="$tmp/calls.log"

  PATH="$fake_bin:$PATH" "$BIN" dispatch "$plan_dir" >/dev/null
  "$BIN" status "$plan_dir" > "$tmp/status.txt"
  "$BIN" collect "$plan_dir" > "$tmp/collect.txt"

  assert_file_contains "$tmp/status.txt" "explore"
  assert_file_contains "$tmp/status.txt" "done"
  assert_file_contains "$tmp/collect.txt" "## explore"
  assert_file_contains "$tmp/collect.txt" "agent=explorer"
}

test_open_does_not_fail_without_cmux() {
  local tmp
  tmp="$(mktemp -d)"
  local plan_dir="$tmp/plan"
  make_fixture "$plan_dir"

  mkdir -p "$tmp/empty-bin"
  PATH="$tmp/empty-bin:/usr/bin:/bin" "$BIN" open "$plan_dir" > "$tmp/open.txt"

  assert_file_contains "$tmp/open.txt" "$plan_dir"
}

test_dispatch_rejects_missing_dispatch_file() {
  local tmp
  tmp="$(mktemp -d)"

  if "$BIN" dispatch "$tmp" >"$tmp/out.txt" 2>"$tmp/err.txt"; then
    fail "dispatch should fail when dispatch.json is missing"
  fi

  assert_file_contains "$tmp/err.txt" "dispatch.json"
}

test_dispatch_writes_failed_status() {
  local tmp
  tmp="$(mktemp -d)"
  local fake_bin="$tmp/bin"
  local plan_dir="$tmp/plan"
  make_fixture "$plan_dir"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/kiro-cli" <<'SH'
#!/usr/bin/env bash
echo "boom" >&2
exit 7
SH
  chmod +x "$fake_bin/kiro-cli"

  if PATH="$fake_bin:$PATH" "$BIN" dispatch "$plan_dir" >"$tmp/out.txt" 2>"$tmp/err.txt"; then
    fail "dispatch should fail when kiro-cli fails"
  fi

  assert_json_value "$plan_dir/kiro/status.json" '.jobs.explore.status' "failed"
  assert_json_value "$plan_dir/kiro/status.json" '.jobs.explore.exitCode' "7"
}

test_dispatch_writes_outputs_and_status
test_status_and_collect_read_plan_outputs
test_open_does_not_fail_without_cmux
test_dispatch_rejects_missing_dispatch_file
test_dispatch_writes_failed_status

echo "ok - codex-kiro adapter tests"
