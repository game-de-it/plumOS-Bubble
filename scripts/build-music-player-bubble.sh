#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
image=${PLUMOS_BUBBLE_APPS_IMAGE:-plumos-mf-toolchain:dev}
if [[ ${1:-} != --inside ]]; then
    exec docker run --rm --platform linux/arm64 -v "$repo_root:/work" -w /work \
        "$image" ./scripts/build-music-player-bubble.sh --inside
fi

build_root=/work/build/music-player-bubble
out=/work/output/music-player/bubble
root=$out/plumos
app=$root/apps/music-player
source_ref=${MUSIC_SOURCE_REF:-bc49dafe782173f35ab557035fa96ba81564038d}
source_base=${MUSIC_SOURCE_BASE:-https://raw.githubusercontent.com/game-de-it/plumOS-V90S_V2/$source_ref}
source_sha=930349bf23de57b2f0d04db1fe0b78e58301e551d292edf015fb742298f4fcd7
renderer_sha=98d40e0dd437c2e6e7a94d751459af94579cc8ed0ae16065d2d4f89e7323e171
miniaudio_ref=9634bedb5b5a2ca38c1ee7108a9358a4e233f14d
miniaudio_sha=ac7af4de748b7e26b777f37e01cee313a308a7296a3eb080e2906b320cc55c89

fetch() {
    curl -LfsS "$1" -o "$2"
    printf '%s  %s\n' "$3" "$2" | sha256sum -c -
}

find_target_lib() {
    local name=$1 dir
    for dir in /lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu /lib /usr/lib; do
        [[ -e $dir/$name ]] && { readlink -f "$dir/$name"; return; }
    done
    return 1
}

copy_deps() {
    local elf=$1 destination=$2 dependency source real
    readelf -d "$elf" 2>/dev/null | awk -F'[][]' '/NEEDED/ {print $2}' |
        while IFS= read -r dependency; do
            case $dependency in
                ld-linux-aarch64.so.1) continue ;;
            esac
            [[ -e $destination/$dependency ]] && continue
            source=$(find_target_lib "$dependency" || true)
            [[ -n $source ]] || { printf 'error: dependency missing: %s\n' "$dependency" >&2; exit 1; }
            real=$(basename "$source")
            install -m 0644 "$source" "$destination/$real"
            [[ $real == "$dependency" ]] || cp -f "$destination/$real" "$destination/$dependency"
            copy_deps "$source" "$destination"
        done
}

rm -rf "$build_root" "$out"
mkdir -p "$build_root/apps" "$build_root/frontend" "$build_root/include" \
    "$app/bin" "$app/lib" "$root/bin" "$root/components/music-player" \
    "$root/share/doc/music-player"
fetch "$source_base/src/apps/plumos_music_player.c" "$build_root/apps/plumos_music_player.c" "$source_sha"
fetch "$source_base/src/apps/plumos_music_v90s_renderer.h" "$build_root/apps/plumos_music_v90s_renderer.h" "$renderer_sha"
fetch "https://raw.githubusercontent.com/mackron/miniaudio/$miniaudio_ref/miniaudio.h" \
    "$build_root/include/miniaudio.h" "$miniaudio_sha"
cp /work/src/frontend/plumos_fbdev_renderer.h "$build_root/frontend/plumos_fbdev_renderer.h"
patch -d "$build_root/apps" -p1 </work/docker/bubble-tools/patches/music-player-bubble.patch
# Linux BTN_A/BTN_B names follow cardinal position, not Bubble's printed labels.
sed -i 's/case BTN_A:/case BTN_EAST:/; s/case BTN_B:/case BTN_SOUTH:/; s#/run/plumos/sd2#/run/media/sd2#g' \
    "$build_root/apps/plumos_music_player.c"

gcc -std=c11 -O2 -pipe -DPLUMOS_FBDEV_ENABLE_FREETYPE=1 \
    -DPLUMOS_FBDEV_ENABLE_PNG=1 -DPLUMOS_FBDEV_ENABLE_DRM=1 \
    -DPLUMOS_MUSIC_ENABLE_ALSA=1 -I"$build_root/include" -I"$build_root/apps" \
    -I"$build_root/frontend" $(pkg-config --cflags freetype2 libpng alsa libdrm) \
    -o "$app/bin/plumos-music-player.bin" "$build_root/apps/plumos_music_player.c" \
    -lasound -ldl -lfreetype -lpng -ljpeg -lz -ldrm -lm -lpthread
strip "$app/bin/plumos-music-player.bin" 2>/dev/null || true
copy_deps "$app/bin/plumos-music-player.bin" "$app/lib"
loader=$(find_target_lib ld-linux-aarch64.so.1)
install -m 0755 "$loader" "$app/lib/ld-linux-aarch64.so.1"

cat >"$root/bin/plumos-music-player-launch" <<'EOF'
#!/bin/sh
set -u
PLUMOS_ROOT=${PLUMOS_ROOT:-/storage/plumos}
BB=${PLUMOS_BUSYBOX:-/bin/busybox}
APP_ROOT=${PLUMOS_MUSIC_PLAYER_ROOT:-$PLUMOS_ROOT/apps/music-player}
STATE_DIR=${PLUMOS_MUSIC_PLAYER_STATE:-$PLUMOS_ROOT/state/apps/music-player}
LOG_DIR=${PLUMOS_MUSIC_PLAYER_LOG_DIR:-$PLUMOS_ROOT/logs/apps}
mkdir -p "$STATE_DIR/.config" "$LOG_DIR" || exit 1
[ -x "$APP_ROOT/bin/plumos-music-player.bin" ] || exit 127
"$BB" sh "$PLUMOS_ROOT/bin/plumos-audio-output" prepare >>"$LOG_DIR/music-player.log" 2>&1 || exit 1
"$BB" sh "$PLUMOS_ROOT/bin/plumos-volume-control" apply >>"$LOG_DIR/music-player.log" 2>&1 || true
export HOME=$STATE_DIR XDG_CONFIG_HOME=$STATE_DIR/.config PLUMOS_ROOT
export PLUMOS_MUSIC_FONT=${PLUMOS_MUSIC_FONT:-$PLUMOS_ROOT/fonts/default.otf}
export PLUMOS_MUSIC_FALLBACK_FONT=${PLUMOS_MUSIC_FALLBACK_FONT:-$PLUMOS_ROOT/fonts/cjk-fallback.ttc}
export ALSA_CONFIG_PATH=${ALSA_CONFIG_PATH:-/run/plumos/audio/asound.conf}
export ALSA_PLUGIN_DIR=${ALSA_PLUGIN_DIR:-$PLUMOS_ROOT/lib/alsa-lib}
export PLUMOS_MUSIC_ALSA_DEVICE=${PLUMOS_MUSIC_ALSA_DEVICE:-plumos_output}
export PLUMOS_MUSIC_IGNORE_ANALOG=1 PLUMOS_DRM_DEVICE=${PLUMOS_DRM_DEVICE:-/dev/dri/card0}
cd "$APP_ROOT" || exit 1
exec "$APP_ROOT/lib/ld-linux-aarch64.so.1" \
  --library-path "$APP_ROOT/lib" \
  "$APP_ROOT/bin/plumos-music-player.bin" >>"$LOG_DIR/music-player.log" 2>&1
EOF
chmod 0755 "$root/bin/plumos-music-player-launch"

cat >"$root/components/music-player/manifest.json" <<EOF
{"name":"plumOS Music Player for Bubble","component":"music-player","device":"bubble","architecture":"aarch64","source_ref":"$source_ref","source_sha256":"$source_sha","miniaudio_ref":"$miniaudio_ref","display":"DRM 640x480","audio":"ALSA plumos_output","input":"GKD Bubble physical mapping"}
EOF
printf 'plumOS Music Player for Bubble\nsource_ref=%s\n' "$source_ref" >"$root/share/doc/music-player/README.txt"
(
    cd "$root"
    find apps/music-player bin/plumos-music-player-launch share/doc/music-player \
        components/music-player/manifest.json -type f -print | sort |
        while IFS= read -r path; do sha256sum "$path"; done
) >"$root/components/music-player/checksums.sha256"
(cd "$root" && sha256sum -c components/music-player/checksums.sha256)
readelf -h "$app/bin/plumos-music-player.bin" | grep -q 'Machine:.*AArch64'
printf 'bubble_music_player=result-ok root=%s\n' "$root"
