#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HOOK="$ROOT/hooks/shell/rtk-rewrite.js"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin" "$tmpdir/home/.cache"

cat > "$tmpdir/bin/rtk" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  --version)
    echo "rtk 0.23.0"
    ;;
  rewrite)
    case "$2" in
      "git status")
        echo "rtk git status"
        ;;
      "unchanged")
        echo "unchanged"
        ;;
      "fail")
        exit 9
        ;;
    esac
    ;;
esac
EOF
chmod +x "$tmpdir/bin/rtk"

run_hook() {
  local command="$1"
  (
    PATH="$tmpdir/bin:$PATH" HOME="$tmpdir/home" printf '%s\n' '{"tool_input":{"command":"'"$command"'"}}' \
      | PATH="$tmpdir/bin:$PATH" HOME="$tmpdir/home" "$HOOK"
  )
}

assert_blocks_rewritten_command() {
  local err="$tmpdir/rewrite.err"

  if run_hook "git status" 2>"$err"; then
    echo "expected rewritten command to block" >&2
    exit 1
  fi

  grep -q "Run this instead: rtk git status" "$err" || { cat "$err" >&2; exit 1; }
}

assert_allows_unchanged_command() {
  run_hook "unchanged"
}

assert_allows_rtk_failure() {
  run_hook "fail"
}

assert_ignores_missing_command() {
  (
    PATH="$tmpdir/bin:$PATH" HOME="$tmpdir/home" printf '%s\n' '{"tool_input":{}}' \
      | PATH="$tmpdir/bin:$PATH" HOME="$tmpdir/home" "$HOOK"
  )
}

assert_blocks_rewritten_command
assert_allows_unchanged_command
assert_allows_rtk_failure
assert_ignores_missing_command

echo "rtk-rewrite tests passed"
