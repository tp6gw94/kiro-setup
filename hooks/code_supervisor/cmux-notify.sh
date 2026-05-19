#!/bin/bash
cmux ping >/dev/null 2>&1 || exit 0

EVENT=$(cat)
CWD=$(echo "$EVENT" | jq -r '.cwd // empty')
RESPONSE=$(echo "$EVENT" | jq -r '.assistant_response // empty')

PROJECT=$(basename "$CWD")
SUMMARY=$(echo "$RESPONSE" | head -c 80 | tr '\n' ' ')

cmux notify \
  --title "Kiro CLI — $PROJECT" \
  --subtitle "$CWD" \
  --body "${SUMMARY}…"
