#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT_DIR/hooks/phase-reminder.sh"

output="$("$HOOK")"

require_contains() {
  local expected="$1"
  if [[ "$output" != *"$expected"* ]]; then
    echo "Expected reminder to contain: $expected" >&2
    echo "Actual output:" >&2
    echo "$output" >&2
    exit 1
  fi
}

require_contains "NON-NEGOTIABLE WORKFLOW REMINDER"
require_contains "Before any write/shell/subagent tool"
require_contains ".plan/"
require_contains "Delegation check"
require_contains "Verify before final"
require_contains "If blocked"

echo "phase reminder hook ok"
