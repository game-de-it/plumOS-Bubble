#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app_root=${PLUMOS_BUBBLE_APP_ROOT:-$repo_root/output/app-layer/bubble/plumos}
coverage=$repo_root/package/frontend-bubble/plumos/config/frontend/runtime-coverage.json

test -f "$app_root/components/libretro-cores/manifest.json"
generated=$(mktemp "${TMPDIR:-/tmp}/bubble-runtime-coverage-test.XXXXXX")
trap 'rm -f "$generated"' EXIT HUP INT TERM

"$repo_root/scripts/generate-bubble-runtime-coverage.py" \
    --app-root "$app_root" --output "$generated"
cmp "$coverage" "$generated"

PLUMOS_BUBBLE_APP_ROOT=$app_root \
    "$repo_root/scripts/verify-bubble-emulator-catalog.sh"

printf '%s\n' 'bubble_runtime_coverage=result-ok systems=98 profiles=196 core_records=114'
