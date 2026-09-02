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
grep -qx 'video_threaded = "true"' "$factory"
grep -qx 'audio_device = "hw:0,0"' "$factory"
grep -qx 'audio_latency = "64"' "$factory"
grep -qx 'input_menu_toggle_btn = "10"' "$factory"
grep -qx 'input_state_slot_increase_btn = "16"' "$factory"
grep -qx 'input_state_slot_decrease_btn = "15"' "$factory"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
root=$tmp/plumos
mkdir -p "$root/bin" "$root/factory-defaults/retroarch"
cp "$helper" "$root/bin/plumos-retroarch-config-merge"
cp "$factory" "$root/factory-defaults/retroarch/retroarch-bubble.cfg"
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

printf 'bubble_retroarch_config_test=result-ok keys=%s duplicates=0\n' "$key_count"
