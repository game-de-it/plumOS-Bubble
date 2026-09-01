#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
image=${PLUMOS_BUBBLE_TOOLS_IMAGE:-plumos-bubble-tools:dev}
docker build --platform linux/arm64 -t "$image" \
    -f "$repo_root/docker/bubble-tools/Dockerfile" "$repo_root"
