#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
patch=$repo_root/patches/retroarch/019-bubble-drm-core-rotation-contract.patch

grep -q 'drm_set_rotation,' "$patch"
grep -q 'retroarch_get_core_requested_rotation' "$patch"
grep -q 'core_rotation = rotation & 3' "$patch"
grep -q 'layer == 2' "$patch"
grep -q 'Bubble display-contract' "$patch"
grep -q 'logical_width' "$patch"
grep -q 'logical_height' "$patch"
grep -q 'new_aspect = 1.0f / new_aspect' "$patch"

if [ -f "$repo_root/output/retroarch/bubble/plumos/bin/retroarch" ]; then
    strings "$repo_root/output/retroarch/bubble/plumos/bin/retroarch" |
        grep -q 'Bubble display-contract'
    strings "$repo_root/output/retroarch/bubble/plumos/bin/retroarch" |
        grep -q 'Bubble rotations panel='
fi

printf 'bubble_retroarch_display_contract=result-ok panel=landscape core_rotation=software aspect=fit\n'
