#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HOOK="$ROOT/hooks/shell/validate-local-rm.js"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

workspace="$tmpdir/workspace"
outside="$tmpdir/outside"
mkdir -p "$workspace/dir" "$outside"
touch "$workspace/file.txt" "$workspace/dir/file.txt" "$outside/file.txt"
ln -s "$outside/file.txt" "$workspace/link-to-outside"

out="$tmpdir/local-rm.out"
err="$tmpdir/local-rm.err"

run_hook() {
  local command="$1"
  (
    cd "$workspace"
    printf '{"cwd":"%s","tool_input":{"command":"%s"}}\n' "$workspace" "$command" | "$HOOK"
  )
}

assert_allows() {
  local command="$1"

  if ! run_hook "$command" >"$out" 2>"$err"; then
    echo "expected command to be allowed: $command" >&2
    cat "$err" >&2
    exit 1
  fi
}

assert_blocks() {
  local command="$1"
  local pattern="$2"

  if run_hook "$command" >"$out" 2>"$err"; then
    echo "expected command to be blocked: $command" >&2
    exit 1
  fi

  if ! grep -q "$pattern" "$err"; then
    echo "expected error to match: $pattern" >&2
    cat "$err" >&2
    exit 1
  fi
}

assert_allows "rtk rm file.txt"
assert_allows "rtk rm -rf dir"
assert_allows "rm ./file.txt"
assert_allows "rtk rm file.txt dir/file.txt"
assert_allows "rtk rm -- file.txt"

assert_blocks "rtk rm /tmp/file" "absolute paths"
assert_blocks "rtk rm ../outside/file.txt" "outside current directory"
assert_blocks "rtk rm link-to-outside" "outside current directory"
assert_blocks "rtk rm *.tmp" "dynamic shell syntax"
assert_blocks "rtk rm file.txt && echo hacked" "dynamic shell syntax"
assert_blocks "rtk rm" "missing a target"

echo "validate-local-rm tests passed"
