#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [options] [sbx-run-args...]

Options:
  --name <sandbox-name>      Name for a newly created sandbox
  --existing <sandbox-name>  Reuse an existing sandbox instead of creating one
  --workspace <path>         Workspace path for sandbox creation (default: .)
  -h, --help                 Show this help

New sandboxes use template kiro-sandbox-template:v1 and kit \$HOME/.kiro/kits/kiro-sandbox.
EOF
}

fail_usage() {
  usage >&2
  exit 1
}

sandbox_name="r-$(openssl rand -hex 4)"
existing_sandbox=""
workspace="."
kit="$HOME/.kiro/kits/kiro-sandbox"
run_args=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --name)
      [ -n "${2:-}" ] || fail_usage
      sandbox_name="$2"
      shift 2
      ;;
    --existing)
      [ -n "${2:-}" ] || fail_usage
      existing_sandbox="$2"
      shift 2
      ;;
    --workspace)
      [ -n "${2:-}" ] || fail_usage
      workspace="$2"
      shift 2
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        run_args+=("$1")
        shift
      done
      ;;
    --*)
      echo "Unknown option: $1" >&2
      fail_usage
      ;;
    *)
      run_args+=("$1")
      shift
      ;;
  esac
done

if [ -n "$existing_sandbox" ]; then
  run_sandbox="$existing_sandbox"
else
  run_sandbox="$sandbox_name"
fi

create_command=(sbx create -t kiro-sandbox-template:v1 --kit "$kit" --name "$sandbox_name" kiro "$workspace")
if [ "${#run_args[@]}" -gt 0 ]; then
  run_command=(sbx run "$run_sandbox" "${run_args[@]}")
else
  run_command=(sbx run "$run_sandbox")
fi

if [ "${SBX_DRY_RUN:-}" = "1" ]; then
  if [ -z "$existing_sandbox" ]; then
    echo "sbx create command: ${create_command[*]}"
  fi
  echo "sbx run command: ${run_command[*]}"
  exit 0
fi

if [ -z "$existing_sandbox" ]; then
  "${create_command[@]}"
fi

exec "${run_command[@]}"
