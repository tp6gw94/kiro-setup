#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: build-kiro-sandbox-template.sh <image-tag>

Builds a Docker Sandbox template image with this Kiro setup baked into
/home/agent/.kiro.

Example:
  ./build-kiro-sandbox-template.sh kiro-sandbox-template:v1
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$#" -ne 1 ]]; then
  usage >&2
  exit 1
fi

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
IMAGE_TAG="$1"
BUILD_CONTEXT=$(mktemp -d)
trap 'rm -rf "$BUILD_CONTEXT"' EXIT

mkdir -p "$BUILD_CONTEXT/home/agent"
bash "$ROOT/sync-kit-skills.sh"
cp -R -L "$ROOT/kits/kiro-sandbox/files/home/." "$BUILD_CONTEXT/home/agent/"

cat > "$BUILD_CONTEXT/home/agent/.gitconfig" <<'GITCONFIG'
[init]
	defaultBranch = main
[safe]
	directory = *
GITCONFIG

cp "$ROOT/Dockerfile.kiro-sandbox" "$BUILD_CONTEXT/Dockerfile.kiro-sandbox"

docker build -f "$BUILD_CONTEXT/Dockerfile.kiro-sandbox" -t "$IMAGE_TAG" "$BUILD_CONTEXT"
