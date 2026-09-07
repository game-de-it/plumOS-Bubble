#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
build=$repo_root/scripts/build-bubble-retroarch.sh
game_launcher=$repo_root/package/frontend-bubble/plumos/bin/plumos-retroarch-launch
menu_launcher=$repo_root/package/frontend-bubble/plumos/bin/plumos-retroarch-menu-launch
factory=$repo_root/configs/retroarch/bubble-software-drm.cfg

for option in --enable-rgui --enable-xmb --enable-ozone; do
    grep -q -- "$option" "$build"
done
grep -Eq '^assets_ref=[0-9a-f]{40}$' "$build"
for tree in fonts glui ozone pkg rgui sounds xmb; do
    grep -q 'for asset_tree in fonts glui ozone pkg rgui sounds xmb' "$build"
done
grep -q 'menu_ctx_ozone menu_ctx_xmb' "$build"
grep -q '"menu_drivers": \["rgui", "xmb", "ozone"\]' "$build"
grep -qx 'assets_directory = "/storage/plumos/retroarch/assets"' "$factory"
grep -qx 'menu_driver = "rgui"' "$factory"
grep -q '\*:\*:xmb|\*:\*:ozone' "$game_launcher"
grep -q 'xmb|ozone)' "$menu_launcher"
grep -q 'video_driver = "gl"' "$menu_launcher"

if [ -f "$repo_root/output/retroarch/bubble/plumos/bin/retroarch" ]; then
    for symbol in menu_ctx_rgui menu_ctx_ozone menu_ctx_xmb; do
        nm "$repo_root/output/build/retroarch-bubble-v1.22.2/retroarch" |
            grep -Eq "[[:space:]]${symbol}$"
    done
    for tree in fonts glui ozone pkg rgui sounds xmb; do
        test -d "$repo_root/output/retroarch/bubble/plumos/retroarch/assets/$tree"
    done
fi

printf 'bubble_retroarch_menu_assets=result-ok default=rgui optional=xmb,ozone backend=gl\n'
