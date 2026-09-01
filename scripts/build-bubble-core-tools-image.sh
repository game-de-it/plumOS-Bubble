#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
image=${PLUMOS_BUBBLE_DOCKER_IMAGE:-plumos-bubble-core-tools:dev}

exec docker build --platform linux/arm64 -t "$image" \
    -f "$repo_root/docker/plumos-bubble-core-tools/Dockerfile" "$repo_root"
