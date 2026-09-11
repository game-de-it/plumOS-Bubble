#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BUILD_ROOT="$ROOT_DIR/output/build/yabasanshiro-bubble"
SOURCE_ROOT="$BUILD_ROOT/yabause"
BUILD_DIR="$BUILD_ROOT/build"
OUT_ROOT="$ROOT_DIR/${PLUMOS_BUBBLE_YABASANSHIRO_OUT:-output/yabasanshiro/bubble}"
YABASANSHIRO_REPO="${YABASANSHIRO_REPO:-https://github.com/libretro/yabause.git}"
YABASANSHIRO_REF="8406a5c11d7b6186a44c7fe48f493e6de5f8cb18"
ARM64_PATCH="$ROOT_DIR/patches/libretro-cores-bubble/yabasanshiro-2.10.4-arm64-gcc12.patch"
STANDALONE_PATCH="$ROOT_DIR/package/standalone-bubble/patches/yabasanshiro/yabasanshiro-2.10.4-bubble-standalone.patch"
FRAMEBUFFER_PATCH="$ROOT_DIR/package/standalone-bubble/patches/yabasanshiro/yabasanshiro-2.10.4-bubble-vdp1-framebuffer-readback.patch"
READBACK_PATCH="$ROOT_DIR/package/standalone-bubble/patches/yabasanshiro/yabasanshiro-2.10.4-bubble-vdp1-readback.patch"
INPUT_PATCH="$ROOT_DIR/package/standalone-bubble/patches/yabasanshiro/yabasanshiro-2.10.4-bubble-input.patch"
SCHED_OTHER_PATCH="$ROOT_DIR/patches/libretro-cores-bubble/yabasanshiro-2.10.4-bubble-sched-other.patch"

for path in \
    "$ARM64_PATCH" \
    "$STANDALONE_PATCH" \
    "$FRAMEBUFFER_PATCH" \
    "$READBACK_PATCH" \
    "$INPUT_PATCH" \
    "$SCHED_OTHER_PATCH"; do
    [ -f "$path" ] || {
        printf 'error: missing YabaSanshiro patch: %s\n' "$path" >&2
        exit 1
    }
done

if [ ! -d "$SOURCE_ROOT/.git" ]; then
    mkdir -p "$BUILD_ROOT"
    git clone --recurse-submodules "$YABASANSHIRO_REPO" "$SOURCE_ROOT"
fi
git -C "$SOURCE_ROOT" fetch --depth 1 origin "$YABASANSHIRO_REF"
git -C "$SOURCE_ROOT" checkout --detach FETCH_HEAD
git -C "$SOURCE_ROOT" reset --hard FETCH_HEAD
git -C "$SOURCE_ROOT" submodule update --init --recursive --depth 1
[ "$(git -C "$SOURCE_ROOT" rev-parse HEAD)" = "$YABASANSHIRO_REF" ] || {
    printf 'error: unexpected YabaSanshiro source ref\n' >&2
    exit 1
}

apply_patch() {
    local patch_file=$1
    if patch --dry-run -d "$SOURCE_ROOT" -p1 <"$patch_file" >/dev/null; then
        patch -d "$SOURCE_ROOT" -p1 <"$patch_file"
    elif ! patch --dry-run -R -d "$SOURCE_ROOT" -p1 <"$patch_file" >/dev/null; then
        printf 'error: YabaSanshiro patch is neither applicable nor applied: %s\n' \
            "$patch_file" >&2
        exit 1
    fi
}

apply_patch "$ARM64_PATCH"
apply_patch "$STANDALONE_PATCH"
apply_patch "$FRAMEBUFFER_PATCH"
apply_patch "$READBACK_PATCH"
apply_patch "$INPUT_PATCH"
# The pinned upstream keeps retro_arena/main.cpp as CRLF while scsp.c is LF.
# Normalize only this source file so GNU patch behaves identically in the
# Linux toolchain container and on the macOS host.
perl -pi -e 's/\r$//' \
    "$SOURCE_ROOT/yabause/src/retro_arena/main.cpp"
apply_patch "$SCHED_OTHER_PATCH"

if grep -Eq \
    'pthread_setschedparam\([^;]*SCHED_(FIFO|RR)' \
    "$SOURCE_ROOT/yabause/src/retro_arena/main.cpp" \
    "$SOURCE_ROOT/yabause/src/scsp.c"; then
    printf 'error: YabaSanshiro Bubble build still requests a realtime scheduler\n' \
        >&2
    exit 1
fi

rm -rf "$BUILD_DIR" "$OUT_ROOT"
mkdir -p "$BUILD_DIR/compat/libpng12" "$OUT_ROOT/lib"
ln -s /usr/include/png.h "$BUILD_DIR/compat/libpng12/png.h"

cmake -S "$SOURCE_ROOT/yabause" -B "$BUILD_DIR" -G 'Unix Makefiles' \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_FLAGS="-I$BUILD_DIR/compat -I/usr/include/SDL2 -D__RETORO_ARENA__ -Wno-error" \
    -DCMAKE_CXX_FLAGS="-I$BUILD_DIR/compat -I/usr/include/SDL2 -D__RETORO_ARENA__ -Wno-error" \
    -DYAB_PORTS=retro_arena \
    -DUSE_EGL=ON \
    -DYAB_FORCE_GLES20=ON \
    -DYAB_WANT_VULKAN=OFF \
    -DYAB_WANT_ARM7=ON \
    -DSH2_DYNAREC=OFF \
    -DYAB_WANT_DYNAREC_DEVMIYAX=ON \
    -DYAB_ASYNC_RENDERING=ON \
    -DSH2_TRACE=OFF \
    -DSDL2_INCLUDE_DIR=/usr/include/SDL2 \
    -DSDL2_LIBRARY=/usr/lib/aarch64-linux-gnu/libSDL2.so
cmake --build "$BUILD_DIR" --target yabause-retro-arena -j"${JOBS:-4}"

binary="$BUILD_DIR/yabause/src/retro_arena/yabasanshiro"
[ -x "$binary" ] || binary="$(find "$BUILD_DIR" -type f -name yabasanshiro -perm -111 | head -n 1)"
[ -x "$binary" ] || {
    printf 'error: YabaSanshiro binary was not produced\n' >&2
    exit 1
}
install -m 0755 "$binary" "$OUT_ROOT/yabasanshiro"
install -m 0644 "$SOURCE_ROOT/LICENSE" "$OUT_ROOT/LICENSE"

copy_runtime_deps() {
    local elf=$1 path soname real real_name
    while IFS= read -r path; do
        [ -f "$path" ] || continue
        soname="$(basename "$path")"
        case "$soname" in
            ld-linux-aarch64.so.1|libc.so.6|libm.so.6|libpthread.so.0|libdl.so.2|librt.so.1|libEGL.so.*|libGLESv2.so.*|libGL.so.*|libmali.so.*)
                continue
                ;;
        esac
        real="$(readlink -f "$path")"
        real_name="$(basename "$real")"
        if [ ! -f "$OUT_ROOT/lib/$real_name" ]; then
            install -m 0644 "$real" "$OUT_ROOT/lib/$real_name"
            copy_runtime_deps "$real"
        fi
        if [ "$soname" != "$real_name" ] && [ ! -e "$OUT_ROOT/lib/$soname" ]; then
            # App-layer checksums intentionally cover regular files only.  Keep
            # each runtime SONAME as a real file so an atomic live update cannot
            # omit a loader-visible symlink from its verified payload.
            install -m 0644 "$real" "$OUT_ROOT/lib/$soname"
        fi
    done < <(
        ldd "$elf" 2>/dev/null |
            awk '/=> \/[^ ]+/ {print $3} /^[[:space:]]*\// {print $1}' |
            sort -u
    )
}
copy_runtime_deps "$OUT_ROOT/yabasanshiro"

printf 'created: %s\n' "$OUT_ROOT"
