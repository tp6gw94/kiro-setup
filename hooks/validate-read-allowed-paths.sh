#!/usr/bin/env bash
set -euo pipefail

payload=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$payload")
[[ -z "$cwd" ]] && cwd="$PWD"

kiro_home=${KIRO_HOME:-$HOME/.kiro}

normalize_path() {
  local base="$1"
  local path="$2"

  python3 - "$base" "$path" <<'PY'
import os
import sys

base, path = sys.argv[1], sys.argv[2]
if not os.path.isabs(path):
    path = os.path.join(base, path)
print(os.path.realpath(os.path.abspath(path)))
PY
}

is_under_or_equal() {
  local path="$1"
  local root="$2"

  [[ "$path" == "$root" || "$path" == "$root"/* ]]
}

block() {
  echo "BLOCKED: code_supervisor cannot read '$1'." >&2
  echo "Allowed read roots are .plan/, KIRO_HOME, and /var/folders." >&2
  exit 2
}

paths=()
while IFS= read -r path; do
  paths+=("$path")
done < <(
  jq -r '
    [
      .tool_input.path?,
      .tool_input.operations[]?.path?
    ]
    | map(select(type == "string" and length > 0))
    | .[]
  ' <<<"$payload"
)

if [[ ${#paths[@]} -eq 0 ]]; then
  echo "BLOCKED: Could not determine read path from tool input." >&2
  echo "Expected .tool_input.path or .tool_input.operations[].path." >&2
  exit 2
fi

plan_root=$(normalize_path "$cwd" ".plan")
kiro_root=$(normalize_path "$cwd" "$kiro_home")
var_root=$(normalize_path "$cwd" "/var/folders")
private_var_root=$(normalize_path "$cwd" "/private/var/folders")

for path in "${paths[@]}"; do
  normalized=$(normalize_path "$cwd" "$path")

  if is_under_or_equal "$normalized" "$plan_root"; then
    continue
  fi
  if is_under_or_equal "$normalized" "$kiro_root"; then
    continue
  fi
  if is_under_or_equal "$normalized" "$var_root"; then
    continue
  fi
  if is_under_or_equal "$normalized" "$private_var_root"; then
    continue
  fi

  block "$path"
done

exit 0
