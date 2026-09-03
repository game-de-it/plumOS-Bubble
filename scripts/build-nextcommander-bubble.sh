#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
image=${PLUMOS_BUBBLE_APPS_IMAGE:-plumos-mf-toolchain:dev}
if [[ ${1:-} != --inside ]]; then
    exec docker run --rm --platform linux/arm64 -v "$repo_root:/work" -w /work \
        "$image" ./scripts/build-nextcommander-bubble.sh --inside
fi

build_root=/work/build/nextcommander-bubble
out=/work/output/nextcommander/bubble
root=$out/plumos
app=$root/apps/nextcommander
source_repo=${NEXTCOMMANDER_REPO:-https://github.com/LoveRetro/NextCommander.git}
source_ref=${NEXTCOMMANDER_REF:-49c24bb67c12aea8078f48c833815f9ef2dcc5e2}
jobs=${JOBS:-2}

find_target_lib() {
    local name=$1 dir
    for dir in /lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu \
        /usr/lib/aarch64-linux-gnu/pulseaudio /lib /usr/lib; do
        [[ -e $dir/$name ]] && { readlink -f "$dir/$name"; return; }
    done
    return 1
}

copy_deps() {
    local elf=$1 destination=$2 dependency source real
    readelf -d "$elf" 2>/dev/null | awk -F'[][]' '/NEEDED/ {print $2}' |
        while IFS= read -r dependency; do
            case $dependency in
                ld-linux-aarch64.so.1|libc.so.6|libm.so.6|libpthread.so.0|libdl.so.2|librt.so.1|libgcc_s.so.1|libstdc++.so.6) continue ;;
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
mkdir -p "$build_root" "$app/bin" "$app/lib" "$app/config" "$root/bin" \
    "$root/components/nextcommander" "$root/share/doc/nextcommander"
git clone --filter=blob:none --no-checkout "$source_repo" "$build_root/source"
git -C "$build_root/source" fetch --depth 1 origin "$source_ref"
git -C "$build_root/source" checkout --detach FETCH_HEAD
patch -d "$build_root/source" -p1 </work/docker/bubble-tools/patches/nextcommander-bubble.patch
patch -d "$build_root/source" -p1 </work/docker/bubble-tools/patches/nextcommander-bubble-screenshot.patch
install -m 0644 /work/src/frontend/plumos_fbdev_renderer.h \
    "$build_root/source/src/plumos_fbdev_renderer.h"
make -C "$build_root/source" -j"$jobs" PLATFORM=bubble PREFIX=/usr
install -m 0755 "$build_root/source/output/NextCommander" "$app/bin/NextCommander"
strip "$app/bin/NextCommander" 2>/dev/null || true
cp -a "$build_root/source/res" "$app/"
install -m 0644 /work/package/frontend-bubble/plumos/fonts/cjk-fallback.ttc "$app/res/font1.ttf"
copy_deps "$app/bin/NextCommander" "$app/lib"
for library in libstdc++.so.6 libgcc_s.so.1; do
    source=$(find_target_lib "$library")
    install -m 0644 "$source" "$app/lib/$library"
    copy_deps "$source" "$app/lib"
done

cat >"$root/bin/plumos-nextcommander-launch" <<'EOF'
#!/bin/sh
set -u
PLUMOS_ROOT=${PLUMOS_ROOT:-/storage/plumos}
SDCARD_ROOT=${PLUMOS_SDCARD_ROOT:-/storage}
APP_ROOT=${PLUMOS_NEXTCOMMANDER_ROOT:-$PLUMOS_ROOT/apps/nextcommander}
STATE_DIR=${PLUMOS_NEXTCOMMANDER_STATE:-$PLUMOS_ROOT/state/apps/nextcommander}
LOG_DIR=${PLUMOS_NEXTCOMMANDER_LOG_DIR:-$PLUMOS_ROOT/logs/apps}
mkdir -p "$STATE_DIR/.cache" "$STATE_DIR/.config" "$LOG_DIR" || exit 1
[ -x "$APP_ROOT/bin/NextCommander" ] || exit 127
config=$STATE_DIR/bubble.cfg
cat >"$config.next" <<CFG
disp_width=640
disp_height=480
disp_bpp=32
disp_ppu_x=2
disp_ppu_y=2
disp_autoscale=false
disp_autoscale_dpi=false
path_default=$SDCARD_ROOT
path_default_right=$SDCARD_ROOT/Roms
path_default_right_fallback=$SDCARD_ROOT/roms
res_dir=$APP_ROOT/res
CFG
mv -f "$config.next" "$config"
export HOME=$STATE_DIR XDG_CACHE_HOME=$STATE_DIR/.cache XDG_CONFIG_HOME=$STATE_DIR/.config
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy SDL_NOMOUSE=1
export PLUMOS_DRM_DEVICE=${PLUMOS_DRM_DEVICE:-/dev/dri/card0}
export LD_LIBRARY_PATH=$APP_ROOT/lib
cd "$APP_ROOT" || exit 1
exec "$APP_ROOT/bin/NextCommander" --config "$config" --res-dir "$APP_ROOT/res" >>"$LOG_DIR/nextcommander.log" 2>&1
EOF
chmod 0755 "$root/bin/plumos-nextcommander-launch"

cat >"$root/components/nextcommander/manifest.json" <<EOF
{"name":"NextCommander for plumOS Bubble","component":"nextcommander","device":"bubble","architecture":"aarch64","upstream":"$source_repo","upstream_ref":"$source_ref","display":"DRM 640x480","input":"GKD Bubble physical mapping"}
EOF
printf 'NextCommander for Bubble\nupstream_ref=%s\n' "$source_ref" >"$root/share/doc/nextcommander/README.txt"
(
    cd "$root"
    find apps/nextcommander bin/plumos-nextcommander-launch share/doc/nextcommander \
        components/nextcommander/manifest.json -type f -print | sort |
        while IFS= read -r path; do sha256sum "$path"; done
) >"$root/components/nextcommander/checksums.sha256"
(cd "$root" && sha256sum -c components/nextcommander/checksums.sha256)
readelf -h "$app/bin/NextCommander" | grep -q 'Machine:.*AArch64'
printf 'bubble_nextcommander=result-ok root=%s\n' "$root"
