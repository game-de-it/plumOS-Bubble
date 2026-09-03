#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
rotation_patch=$repo_root/patches/retroarch/019-bubble-drm-core-rotation-contract.patch
viewport_patch=$repo_root/patches/retroarch/020-bubble-drm-runtime-viewport-menu.patch

grep -q 'drm_set_rotation,' "$rotation_patch"
grep -q 'retroarch_get_core_requested_rotation' "$rotation_patch"
grep -q 'core_rotation = rotation & 3' "$rotation_patch"
grep -q 'layer == 2' "$rotation_patch"
grep -q 'Bubble display-contract' "$rotation_patch"
grep -q 'logical_width' "$rotation_patch"
grep -q 'logical_height' "$rotation_patch"
grep -q 'new_aspect = 1.0f / new_aspect' "$rotation_patch"
grep -q 'logical_width  = surface->viewport.height' "$rotation_patch"
grep -q 'surface->src_width   = surface->viewport.width' "$rotation_patch"

grep -q 'video_viewport_get_scaled_integer' "$viewport_patch"
grep -q 'surface->aspect, keep_aspect' "$viewport_patch"
grep -q 'surface->layer != 2' "$viewport_patch"
grep -q 'surface->aspect   = 4.0f / 3.0f' "$viewport_patch"
grep -q 'menu_view.layer    = 2' "$viewport_patch"
grep -q 'Bubble recreating RGUI surface' "$viewport_patch"
grep -q 'drm_invalidate_surfaces(_drmvars, "runtime video state change")' \
    "$viewport_patch"
grep -q 'drm_invalidate_surfaces(_drmvars, "runtime aspect change")' \
    "$viewport_patch"

if [ -f "$repo_root/output/retroarch/bubble/plumos/bin/retroarch" ]; then
    strings "$repo_root/output/retroarch/bubble/plumos/bin/retroarch" |
        grep -q 'Bubble display-contract'
    strings "$repo_root/output/retroarch/bubble/plumos/bin/retroarch" |
        grep -q 'Bubble rotations panel='
    strings "$repo_root/output/retroarch/bubble/plumos/bin/retroarch" |
        grep -q 'Bubble surfaces invalidated for'
    strings "$repo_root/output/retroarch/bubble/plumos/bin/retroarch" |
        grep -q 'Bubble recreating RGUI surface'
fi

printf 'bubble_retroarch_display_contract=result-ok panel=landscape core_rotation=software aspect=core-provided integer=content-only menu=fixed-4:3\n'
