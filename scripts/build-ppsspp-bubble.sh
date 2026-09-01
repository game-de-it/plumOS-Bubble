#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/build/ppsspp-bubble/source"
BUILD_DIR="$ROOT_DIR/build/ppsspp-bubble/build"
OUT_ROOT="$ROOT_DIR/${PLUMOS_BUBBLE_PPSSPP_OUT:-output/ppsspp/bubble}"
PATCH_FILE="$ROOT_DIR/package/standalone-bubble/patches/ppsspp/ppsspp-1.20.4-bubble-no-sdl2-ttf.patch"
PPSSPP_REPO="${PLUMOS_BUBBLE_PPSSPP_REPO:-https://github.com/hrydgard/ppsspp.git}"
PPSSPP_REF="${PLUMOS_BUBBLE_PPSSPP_REF:-v1.20.4}"
PPSSPP_COMMIT="fa50bb1976065c4f8b1b47af227d367fe9771555"
JOBS="${JOBS:-$(nproc)}"
COMMON_FLAGS="-O3 -mcpu=cortex-a55 -mtune=cortex-a55 -fomit-frame-pointer"

command -v cmake >/dev/null
command -v git >/dev/null
command -v ninja >/dev/null
command -v readelf >/dev/null
[ -s "$PATCH_FILE" ]

if [ ! -d "$SOURCE_DIR/.git" ]; then
    [ ! -e "$SOURCE_DIR" ] || {
        printf 'error: PPSSPP source path exists but is not a Git clone: %s\n' \
            "$SOURCE_DIR" >&2
        exit 1
    }
    mkdir -p "$(dirname "$SOURCE_DIR")"
    git clone --filter=blob:none "$PPSSPP_REPO" "$SOURCE_DIR"
fi
git -C "$SOURCE_DIR" fetch --tags --force origin "$PPSSPP_REF"
[ -z "$(git -C "$SOURCE_DIR" status --porcelain)" ] || {
    printf 'error: PPSSPP source clone has local changes: %s\n' \
        "$SOURCE_DIR" >&2
    exit 1
}
git -C "$SOURCE_DIR" checkout --detach "$PPSSPP_COMMIT"
[ "$(git -C "$SOURCE_DIR" rev-parse HEAD)" = "$PPSSPP_COMMIT" ]
git -C "$SOURCE_DIR" submodule sync --recursive
git -C "$SOURCE_DIR" submodule update --init --recursive
git -C "$SOURCE_DIR" apply --check "$PATCH_FILE"
git -C "$SOURCE_DIR" apply "$PATCH_FILE"

restore_source() {
    git -C "$SOURCE_DIR" apply --reverse "$PATCH_FILE" >/dev/null 2>&1 ||
        true
}
trap restore_source EXIT

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="$COMMON_FLAGS" \
    -DCMAKE_CXX_FLAGS="$COMMON_FLAGS" \
    -DARM64=ON \
    -DARMV7=OFF \
    -DUSING_EGL=OFF \
    -DUSING_FBDEV=ON \
    -DUSING_GLES2=ON \
    -DPLUMOS_BUBBLE=ON \
    -DVULKAN=OFF \
    -DUSING_X11_VULKAN=OFF \
    -DUSE_WAYLAND_WSI=OFF \
    -DUSE_VULKAN_DISPLAY_KHR=OFF \
    -DCMAKE_DISABLE_FIND_PACKAGE_X11=TRUE \
    -DUSE_FFMPEG=ON \
    -DUSE_SYSTEM_FFMPEG=OFF \
    -DUSE_DISCORD=OFF \
    -DUSE_MINIUPNPC=OFF \
    -DUSE_SYSTEM_LIBSDL2=ON \
    -DSDL2_INCLUDE_DIR=/usr/include/SDL2 \
    -DSDL2_LIBRARY=/usr/lib/aarch64-linux-gnu/libSDL2.so \
    -DUSE_SYSTEM_FREETYPE=OFF \
    -DUSE_SYSTEM_LIBCHDR=OFF \
    -DUSE_SYSTEM_LIBZIP=OFF \
    -DUSE_SYSTEM_SNAPPY=OFF \
    -DUSE_SYSTEM_ZSTD=OFF \
    -DHEADLESS=OFF \
    -DUNITTEST=OFF \
    -DATLAS_TOOL=OFF \
    -DUSING_QT_UI=OFF \
    -DMOBILE_DEVICE=OFF \
    -DGOLD=OFF
cmake --build "$BUILD_DIR" --target PPSSPPSDL -j"$JOBS"
strip "$BUILD_DIR/PPSSPPSDL"

file "$BUILD_DIR/PPSSPPSDL" | grep -q 'ELF 64-bit.*ARM aarch64'
PLUMOS_BUBBLE_PPSSPP_COMPILER_FLAGS="$COMMON_FLAGS" \
    "$ROOT_DIR/scripts/package-ppsspp-bubble.sh" \
    "$BUILD_DIR/PPSSPPSDL" "$SOURCE_DIR"
