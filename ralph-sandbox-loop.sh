#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [options] <task-file> <iterations>

Options:
  --name <sandbox-name>              Name for a newly created sandbox
  --existing-sandbox <sandbox-name>  Reuse an existing sandbox instead of creating one
  --workspace <path>                 Workspace path for sandbox creation (default: .)
  -h, --help                         Show this help

New sandboxes use template kiro-sandbox-template:v1 and kit \$HOME/.kiro/kits/kiro-sandbox.
EOF
}

fail_usage() {
  usage >&2
  exit 1
}

ralph_sandbox_name="ralph-$(date +%Y%m%d%H%M%S)-$$"
ralph_existing_sandbox=""
ralph_workspace="."
ralph_kit="$HOME/.kiro/kits/kiro-sandbox"
positional=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --name)
      [ -n "${2:-}" ] || fail_usage
      ralph_sandbox_name="$2"
      shift 2
      ;;
    --existing-sandbox)
      [ -n "${2:-}" ] || fail_usage
      ralph_existing_sandbox="$2"
      shift 2
      ;;
    --workspace)
      [ -n "${2:-}" ] || fail_usage
      ralph_workspace="$2"
      shift 2
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        positional+=("$1")
        shift
      done
      ;;
    --*)
      echo "Unknown option: $1" >&2
      fail_usage
      ;;
    *)
      positional+=("$1")
      shift
      ;;
  esac
done

if [ "${#positional[@]}" -ne 2 ]; then
  fail_usage
fi

task_file="${positional[0]}"
iterations="${positional[1]}"

if [ ! -f "$task_file" ]; then
  echo "task-file must exist: $task_file" >&2
  exit 1
fi

if ! [[ "$iterations" =~ ^[1-9][0-9]*$ ]]; then
  echo "iterations must be a positive integer" >&2
  exit 1
fi

commits=$(git log -n 5 --format="%H%n%ad%n%B---" --date=short 2>/dev/null || echo "No commits found")
mkdir -p .ralph-sandbox-loop
ralph_input_file=".ralph-sandbox-loop/input-$(date +%Y%m%d%H%M%S)-$$.md"
{
  printf 'Read this file and execute exactly one Ralph iteration from it.\n\n'
  printf 'Previous commits:\n%s\n\n' "$commits"
  printf 'Task file: %s\n\n' "$task_file"
  printf 'Task:\n'
  cat "$task_file"
  printf '\n'
} >"$ralph_input_file"

if [ -n "$ralph_existing_sandbox" ]; then
  ralph_run_sandbox="$ralph_existing_sandbox"
else
  ralph_run_sandbox="$ralph_sandbox_name"
fi

sbx_create_command=(sbx create -t kiro-sandbox-template:v1 --kit "$ralph_kit" --name "$ralph_sandbox_name" kiro "$ralph_workspace")
sbx_command=(sbx run "$ralph_run_sandbox" -- chat --no-interactive --trust-all-tools --agent ralph "$ralph_input_file")

if [ "${RALPH_DRY_RUN:-}" = "1" ]; then
  if [ -z "$ralph_existing_sandbox" ]; then
    echo "sbx create command: ${sbx_create_command[*]}"
  fi
  echo "sbx command: ${sbx_command[*]}"
  echo "generated input: $ralph_input_file"
  exit 0
fi

if [ -z "$ralph_existing_sandbox" ]; then
  "${sbx_create_command[@]}"
fi

for ((i = 1; i <= iterations; i++)); do
  tmpfile=$(mktemp)

  cleanup() {
    rm -f "$tmpfile"
  }
  trap cleanup EXIT

  "${sbx_command[@]}" | tee "$tmpfile"

  if grep -q '<promise>NO MORE TASKS</promise>' "$tmpfile"; then
    echo "Ralph complete after $i iterations."
    exit 0
  fi

  rm -f "$tmpfile"
  trap - EXIT
done
