#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
image=${PLUMOS_BUBBLE_TOOLS_IMAGE:-plumos-bubble-tools:dev}
if [ "${1:-}" != --inside ]; then
    exec docker run --rm --platform linux/arm64 \
        -v "$repo_root:/work" -w /work "$image" \
        ./tests/test-bubble-retroarch-config.sh --inside
fi

factory=$repo_root/configs/retroarch/bubble-software-drm.cfg
legacy_defaults=$repo_root/configs/retroarch/bubble-pre-v90s-expanded.cfg
helper=$repo_root/package/frontend-bubble/plumos/bin/plumos-retroarch-config-merge
key_count=$(awk '$0 ~ /^[A-Za-z0-9_.-]+[[:space:]]*=/ { count++ } END { print count + 0 }' "$factory")
unique_count=$(awk '
    $0 ~ /^[A-Za-z0-9_.-]+[[:space:]]*=/ {
        key=$0
        sub(/[[:space:]]*=.*/, "", key)
        seen[key]=1
    }
    END { print length(seen) }
' "$factory")
test "$key_count" -eq 3376
test "$unique_count" -eq 3376
! grep -Eq '/mnt/plumos|/mnt/plumos-user|^.*Pixel2.*=' "$factory"
grep -qx 'video_driver = "drm"' "$factory"
grep -qx 'video_context_driver = ""' "$factory"
grep -qx 'video_rotation = "0"' "$factory"
grep -qx 'video_aspect_ratio_auto = "true"' "$factory"
grep -qx 'video_threaded = "true"' "$factory"
grep -qx 'audio_device = "hw:0,0"' "$factory"
grep -qx 'audio_latency = "64"' "$factory"
grep -qx 'input_menu_toggle_btn = "17"' "$factory"
grep -qx 'input_screenshot_btn = "10"' "$factory"
grep -qx 'input_hold_fast_forward_btn = "nul"' "$factory"
grep -qx 'input_rewind_btn = "nul"' "$factory"
grep -qx 'input_state_slot_increase_btn = "16"' "$factory"
grep -qx 'input_state_slot_decrease_btn = "15"' "$factory"
grep -qx 'input_player1_up_btn = "13"' "$factory"
grep -qx 'input_player1_down_btn = "14"' "$factory"
grep -qx 'input_player1_left_btn = "15"' "$factory"
grep -qx 'input_player1_right_btn = "16"' "$factory"
grep -qx 'input_player1_l3_btn = "11"' "$factory"
grep -qx 'input_player1_r3_btn = "12"' "$factory"
grep -qx 'input_player1_r_x_minus_axis = "-2"' "$factory"
grep -qx 'input_player1_r_y_plus_axis = "+3"' "$factory"
legacy_count=$(awk '$0 ~ /^[A-Za-z0-9_.-]+[[:space:]]*=/ { count++ } END { print count + 0 }' "$legacy_defaults")
test "$legacy_count" -eq 123

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
root=$tmp/plumos
mkdir -p "$root/bin" "$root/factory-defaults/retroarch"
cp "$helper" "$root/bin/plumos-retroarch-config-merge"
cp "$factory" "$root/factory-defaults/retroarch/retroarch-bubble.cfg"
cp "$legacy_defaults" \
    "$root/factory-defaults/retroarch/retroarch-bubble-pre-v90s.cfg"
chmod 0755 "$root/bin/plumos-retroarch-config-merge"

PLUMOS_ROOT=$root PLUMOS_BUSYBOX=/bin/busybox \
    "$root/bin/plumos-retroarch-config-merge" >"$tmp/install.log"
grep -q '^retroarch_config=result-installed ' "$tmp/install.log"
cmp "$factory" "$root/config/retroarch/retroarch-bubble.cfg"

printf '%s\n' \
    'video_threaded = "false"' \
    'audio_resampler = "custom-user-value"' \
    >"$root/config/retroarch/retroarch-bubble.cfg"
rm -f "$root/state/retroarch/factory-config.sha256"
PLUMOS_ROOT=$root PLUMOS_BUSYBOX=/bin/busybox \
    "$root/bin/plumos-retroarch-config-merge" >"$tmp/merge.log"
grep -q '^retroarch_config=result-merged ' "$tmp/merge.log"
grep -qx 'video_threaded = "false"' "$root/config/retroarch/retroarch-bubble.cfg"
grep -qx 'audio_resampler = "custom-user-value"' "$root/config/retroarch/retroarch-bubble.cfg"
merged_unique=$(awk '
    $0 ~ /^[A-Za-z0-9_.-]+[[:space:]]*=/ {
        key=$0
        sub(/[[:space:]]*=.*/, "", key)
        seen[key]=1
    }
    END { print length(seen) }
' "$root/config/retroarch/retroarch-bubble.cfg")
test "$merged_unique" -eq 3376

PLUMOS_ROOT=$root PLUMOS_BUSYBOX=/bin/busybox \
    "$root/bin/plumos-retroarch-config-merge" >"$tmp/idempotent.log"
grep -q '^retroarch_config=result-unchanged ' "$tmp/idempotent.log"

# The first full Bubble migration filled only missing keys, so RetroArch kept
# its serialized pre-port defaults. Migrate those exact values while preserving
# explicit user choices made after that generation.
legacy_root=$tmp/legacy/plumos
mkdir -p "$legacy_root/bin" "$legacy_root/factory-defaults/retroarch" \
    "$legacy_root/config/retroarch" "$legacy_root/state/retroarch"
cp "$helper" "$legacy_root/bin/plumos-retroarch-config-merge"
cp "$factory" \
    "$legacy_root/factory-defaults/retroarch/retroarch-bubble.cfg"
cp "$legacy_defaults" \
    "$legacy_root/factory-defaults/retroarch/retroarch-bubble-pre-v90s.cfg"
chmod 0755 "$legacy_root/bin/plumos-retroarch-config-merge"
awk '
    NR == FNR {
        if ($0 ~ /^[A-Za-z0-9_.-]+[[:space:]]*=/) {
            key=$0
            sub(/[[:space:]]*=.*/, "", key)
            legacy[key]=$0
        }
        next
    }
    {
        line=$0
        if ($0 ~ /^[A-Za-z0-9_.-]+[[:space:]]*=/) {
            key=$0
            sub(/[[:space:]]*=.*/, "", key)
            if (key in legacy)
                line=legacy[key]
        }
        print line
    }
' "$legacy_defaults" "$factory" >"$legacy_root/config/retroarch/retroarch-bubble.cfg"
sed -i 's/^rgui_menu_color_theme = "4"$/rgui_menu_color_theme = "23"/' \
    "$legacy_root/config/retroarch/retroarch-bubble.cfg"
sed -i 's/^audio_resampler = "sinc"$/audio_resampler = "user-resampler"/' \
    "$legacy_root/config/retroarch/retroarch-bubble.cfg"
printf '%s\n' '0a10e596d378325e9449fa8374f3f62d9c198461b3db4a69f61634824ddc638a' \
    >"$legacy_root/state/retroarch/factory-config.sha256"
PLUMOS_ROOT=$legacy_root PLUMOS_BUSYBOX=/bin/busybox \
    "$legacy_root/bin/plumos-retroarch-config-merge" >"$tmp/legacy.log"
grep -q '^retroarch_config=result-migrated-pre-v90s added=120 ' \
    "$tmp/legacy.log"
legacy_active=$legacy_root/config/retroarch/retroarch-bubble.cfg
grep -qx 'rgui_menu_color_theme = "23"' "$legacy_active"
grep -qx 'audio_resampler = "user-resampler"' "$legacy_active"
grep -qx 'assets_directory = "/storage/plumos/retroarch/assets"' "$legacy_active"
grep -qx 'input_screenshot_btn = "10"' "$legacy_active"
grep -qx 'input_player1_up_btn = "13"' "$legacy_active"
grep -qx 'input_player1_r_y_plus_axis = "+3"' "$legacy_active"
grep -qx 'input_hold_fast_forward_btn = "nul"' "$legacy_active"
grep -qx 'input_rewind_btn = "nul"' "$legacy_active"
test -s "$legacy_root/state/retroarch/pre-v90s-active.cfg"

# Migrate only the exact previously managed Function2-menu pair. This must not
# overwrite an independently changed user binding.
function_root=$tmp/function1/plumos
mkdir -p "$function_root/bin" "$function_root/factory-defaults/retroarch" \
    "$function_root/config/retroarch" "$function_root/state/retroarch"
cp "$helper" "$function_root/bin/plumos-retroarch-config-merge"
cp "$factory" "$function_root/factory-defaults/retroarch/retroarch-bubble.cfg"
cp "$legacy_defaults" \
    "$function_root/factory-defaults/retroarch/retroarch-bubble-pre-v90s.cfg"
chmod 0755 "$function_root/bin/plumos-retroarch-config-merge"
cp "$factory" "$function_root/config/retroarch/retroarch-bubble.cfg"
sed -i \
    -e 's/^input_menu_toggle_btn = "17"$/input_menu_toggle_btn = "10"/' \
    -e 's/^input_screenshot_btn = "10"$/input_screenshot_btn = "17"/' \
    "$function_root/config/retroarch/retroarch-bubble.cfg"
printf '%s\n' '23878b2e84b5145f43925f15aae1a424be75748e84b5ba209fbe7b4231de9635' \
    >"$function_root/state/retroarch/factory-config.sha256"
PLUMOS_ROOT=$function_root PLUMOS_BUSYBOX=/bin/busybox \
    "$function_root/bin/plumos-retroarch-config-merge" >"$tmp/function1.log"
grep -q '^retroarch_config=result-migrated-function1-menu added=2 ' \
    "$tmp/function1.log"
function_active=$function_root/config/retroarch/retroarch-bubble.cfg
grep -qx 'input_menu_toggle_btn = "17"' "$function_active"
grep -qx 'input_screenshot_btn = "10"' "$function_active"
grep -qx 'input_menu_toggle_btn = "10"' \
    "$function_root/state/retroarch/pre-function1-menu-active.cfg"

sed -i 's/^input_menu_toggle_btn = "17"$/input_menu_toggle_btn = "9"/' \
    "$function_active"
printf '%s\n' '23878b2e84b5145f43925f15aae1a424be75748e84b5ba209fbe7b4231de9635' \
    >"$function_root/state/retroarch/factory-config.sha256"
PLUMOS_ROOT=$function_root PLUMOS_BUSYBOX=/bin/busybox \
    "$function_root/bin/plumos-retroarch-config-merge" >"$tmp/function1-user.log"
grep -qx 'input_menu_toggle_btn = "9"' "$function_active"

# Migrate the accidental fixed-4:3 Bubble default only when both the marker
# and the active value identify the old managed generation.
aspect_root=$tmp/aspect/plumos
mkdir -p "$aspect_root/bin" "$aspect_root/factory-defaults/retroarch" \
    "$aspect_root/config/retroarch" "$aspect_root/state/retroarch"
cp "$helper" "$aspect_root/bin/plumos-retroarch-config-merge"
cp "$factory" "$aspect_root/factory-defaults/retroarch/retroarch-bubble.cfg"
cp "$legacy_defaults" \
    "$aspect_root/factory-defaults/retroarch/retroarch-bubble-pre-v90s.cfg"
chmod 0755 "$aspect_root/bin/plumos-retroarch-config-merge"
cp "$factory" "$aspect_root/config/retroarch/retroarch-bubble.cfg"
sed -i 's/^video_aspect_ratio_auto = "true"$/video_aspect_ratio_auto = "false"/' \
    "$aspect_root/config/retroarch/retroarch-bubble.cfg"
printf '%s\n' '04bf95ccb13544c17fe03dabe70024be8ed17e8a40f2ae9e3f313a09f5b82348' \
    >"$aspect_root/state/retroarch/factory-config.sha256"
PLUMOS_ROOT=$aspect_root PLUMOS_BUSYBOX=/bin/busybox \
    "$aspect_root/bin/plumos-retroarch-config-merge" >"$tmp/aspect.log"
grep -q '^retroarch_config=result-migrated-core-aspect added=1 ' \
    "$tmp/aspect.log"
grep -qx 'video_aspect_ratio_auto = "true"' \
    "$aspect_root/config/retroarch/retroarch-bubble.cfg"
test -s "$aspect_root/state/retroarch/pre-core-aspect-active.cfg"

printf 'bubble_retroarch_config_test=result-ok keys=%s duplicates=0\n' "$key_count"
