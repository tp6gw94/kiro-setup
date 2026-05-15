#!/usr/bin/env bash
set -euo pipefail

repo_root=${KIRO_REPO_ROOT:-$PWD}
plan_root="$repo_root/.plan"
marker="$plan_root/.active-developer-plan"

normalize_path() {
  python3 -c "import os,sys; print(os.path.normpath(sys.argv[1]))" "$1"
}

block() {
  echo "BLOCKED: developer requires an approved .plan/<task-name>/task.md before using this tool." >&2
  echo "$1" >&2
  exit 2
}

repo_root=$(normalize_path "$repo_root")
plan_root=$(normalize_path "$plan_root")

if [[ ! -f "$marker" ]]; then
  block "Write the active plan folder path to $marker before delegating to developer."
fi

active_plan=$(head -n 1 "$marker" | tr -d '\r')
if [[ -z "$active_plan" ]]; then
  block "$marker is empty."
fi

if [[ "$active_plan" != /* ]]; then
  if [[ "$active_plan" == .plan/* ]]; then
    active_plan="$repo_root/$active_plan"
  else
    active_plan="$plan_root/$active_plan"
  fi
fi

active_plan=$(normalize_path "$active_plan")
active_parent=$(dirname "$active_plan")

if [[ "$active_parent" != "$plan_root" ]]; then
  block "Active developer plan must point inside .plan as a direct task folder: $active_plan"
fi

if [[ ! -f "$active_plan/task.md" ]]; then
  block "task.md was not found at $active_plan/task.md."
fi

exit 0
