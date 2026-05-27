#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SERVER="$ROOT/mcp/local-fs/server.mjs"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

workspace="$tmpdir/workspace"
outside="$tmpdir/outside"
mkdir -p "$workspace/dir" "$outside"
touch "$workspace/file.txt" "$workspace/dir/file.txt" "$outside/file.txt"
ln -s "$outside" "$workspace/link-outside-dir"
ln -s "$outside/file.txt" "$workspace/link-outside-file"

node "$ROOT/hooks/test-local-fs-mcp-client.mjs" "$SERVER" "$workspace" "$outside"

echo "local-fs MCP tests passed"
