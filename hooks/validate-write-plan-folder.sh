#!/usr/bin/env bash
set -euo pipefail

path=$(jq -r '.tool_input.path' < /dev/stdin)

# Normalize: make absolute then canonicalize
[[ "$path" != /* ]] && path="$PWD/$path"
path=$(python3 -c "import os,sys; print(os.path.normpath(sys.argv[1]))" "$path")

plan_dir=$(python3 -c "import os,sys; print(os.path.normpath(sys.argv[1]))" "$PWD/.plan")

if [[ "$path" == "$plan_dir"/* ]]; then
  exit 0
fi

echo "❌ BLOCKED: code_supervisor cannot write to '$path'." >&2
echo "Only .plan/ is writable. Follow workflow to delegate subagent." >&2
exit 2
