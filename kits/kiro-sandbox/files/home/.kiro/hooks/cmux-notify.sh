#!/bin/bash
EVENT=$(cat)
CWD=$(printf '%s' "$EVENT" | jq -r '.cwd // empty')
SUMMARY=$(printf '%s' "$EVENT" | jq -r '(.assistant_response // "") | gsub("\n"; " ") | .[0:80]')

PROJECT=$(basename "$CWD")

if [ -n "${CMUX_NOTIFY_URL:-}" ]; then
  payload=$(jq -n \
    --arg title "Kiro CLI - $PROJECT" \
    --arg subtitle "$CWD" \
    --arg body "${SUMMARY}..." \
    --arg window "${CMUX_NOTIFY_WINDOW:-}" \
    --arg workspace "${CMUX_NOTIFY_WORKSPACE:-}" \
    --arg surface "${CMUX_NOTIFY_SURFACE:-}" \
    '{title: $title, subtitle: $subtitle, body: $body, cmux: {window: $window, workspace: $workspace, surface: $surface}}')

  if [ -n "${CMUX_NOTIFY_TOKEN:-}" ]; then
    printf '%s' "$payload" | curl -fsS -m 2 \
      -X POST "$CMUX_NOTIFY_URL" \
      -H "Content-Type: application/json" \
      -H "X-Cmux-Notify-Token: ${CMUX_NOTIFY_TOKEN}" \
      --data-binary @- >/dev/null 2>&1 || true
  else
    printf '%s' "$payload" | curl -fsS -m 2 \
      -X POST "$CMUX_NOTIFY_URL" \
      -H "Content-Type: application/json" \
      --data-binary @- >/dev/null 2>&1 || true
  fi
  exit 0
fi

cmux ping >/dev/null 2>&1 || exit 0

cmux notify \
  --title "Kiro CLI - $PROJECT" \
  --subtitle "$CWD" \
  --body "${SUMMARY}..."
