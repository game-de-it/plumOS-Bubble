#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
package="$repo_root/package/frontend-bubble/plumos"
menus="$package/config/frontend/menus.json"
apps="$package/config/frontend/apps.json"
coverage="$package/config/frontend/start-menu-coverage.json"

expected_start='["ui-settings","system-settings","network-settings","performance-settings","apps","help","reboot","shutdown"]'
expected_apps='["scraping","file_manager","music_player","retroarch","pyxel_setup","portmaster","portmaster_update","thumbnail-plan","thumbnail-fetch","thumbnail-results"]'

[[ $(jq -c '[.menus[] | select(.id == "start") | .entries[].id]' "$menus") == "$expected_start" ]]
[[ $(jq -c '[.apps[] | select(.menu == "apps") | .id]' "$apps") == "$expected_apps" ]]
[[ $(jq -c '.start_order' "$coverage") == "$expected_start" ]]
[[ $(jq -c '.apps_order' "$coverage") == "$expected_apps" ]]
jq -e '.bubble_only_start_entries == [] and .bubble_only_apps_entries == []' "$coverage" >/dev/null
jq -e 'all(.start_entries[]; .status == "implemented") and
    all(.apps_entries[]; .status == "implemented")' "$coverage" >/dev/null

for id in scraping file_manager music_player retroarch pyxel_setup portmaster \
    portmaster_update thumbnail-plan thumbnail-fetch thumbnail-results; do
    jq -e --arg id "$id" '.apps[] | select(.id == $id) | (.available // true) == true' "$apps" >/dev/null
done

for lang in "$package"/share/frontend/lang/*.lang; do
    grep -q '^common.not_supported=' "$lang"
    grep -q '^common.not_supported_on_device=' "$lang"
done

for helper in plumos-display-control plumos-network-control plumos-network-services \
    plumos-time-sync plumos-factory-reset plumos-safe-shutdown \
    plumos-thumbnail-scraper; do
    sh -n "$package/bin/$helper"
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/root/config/system" "$tmp/run" "$tmp/backlight"
printf '{"brightness": 10}\n' >"$tmp/root/config/system/settings.json"
printf '0\n' >"$tmp/backlight/brightness"
printf '255\n' >"$tmp/backlight/max_brightness"
PLUMOS_ROOT="$tmp/root" PLUMOS_RUNTIME_ROOT="$tmp/run" \
PLUMOS_BUBBLE_BACKLIGHT="$tmp/backlight/brightness" \
PLUMOS_BUBBLE_MAX_BRIGHTNESS="$tmp/backlight/max_brightness" \
    sh "$package/bin/plumos-display-control" apply 20
[[ $(cat "$tmp/backlight/brightness") == 255 ]]
grep -q '"brightness": 10' "$tmp/root/config/system/settings.json"

mkdir -p "$tmp/factory/retroarch" "$tmp/factory/standalone/ppsspp/PSP/SYSTEM" \
    "$tmp/factory/standalone/yabasanshiro" "$tmp/factory/standalone/pcsx_rearmed"
printf 'ra\n' >"$tmp/factory/retroarch/retroarch.cfg"
printf 'ppsspp\n' >"$tmp/factory/standalone/ppsspp/PSP/SYSTEM/ppsspp.ini"
printf 'controls\n' >"$tmp/factory/standalone/ppsspp/PSP/SYSTEM/controls.ini"
printf '{}\n' >"$tmp/factory/standalone/yabasanshiro/keymapv2.json"
printf 'pcsx\n' >"$tmp/factory/standalone/pcsx_rearmed/pcsx.cfg"
PLUMOS_ROOT="$tmp/root" PLUMOS_FACTORY_DEFAULTS_ROOT="$tmp/factory" \
    sh "$package/bin/plumos-factory-reset" all --dry-run >"$tmp/factory.log"
grep -q 'would restore ra: config/retroarch/retroarch.cfg' "$tmp/factory.log"
grep -q 'would restore sa: config/standalone/ppsspp/ppsspp/PSP/SYSTEM/ppsspp.ini' "$tmp/factory.log"

PLUMOS_ROOT="$tmp/root" PLUMOS_RUNTIME_ROOT="$tmp/run" \
    sh "$package/bin/plumos-safe-shutdown" --reboot --dry-run >"$tmp/power.log"
grep -q 'result=dry-run action=reboot' "$tmp/power.log"

printf 'bubble_start_menu_contract=result-ok start=8 apps=10 implemented=10 bubble_only=0\n'
