#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ -z "$1" ]; then
  echo "Usage: inject-env.sh <sandbox-name>" >&2
  exit 1
fi

name="$1"

for key in EXA_API_KEY FIGMA_API_KEY; do
  sbx exec -d "$name" bash -c "echo 'export ${key}=${!key}' >> /etc/sandbox-persistent.sh"
done
