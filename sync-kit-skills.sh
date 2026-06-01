#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SOURCE="$ROOT/skills"
TARGET="$ROOT/kits/kiro-sandbox/files/home/.kiro/skills"

if [[ ! -d "$SOURCE" ]]; then
  echo "ERROR: source skills directory not found: $SOURCE" >&2
  exit 1
fi

rm -rf "$TARGET"
mkdir -p "$TARGET"

shopt -s dotglob nullglob
for item in "$SOURCE"/*; do
  cp -R -L "$item" "$TARGET/"
done

echo "Copied skills to $TARGET"
