#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SOURCE_ROOT="$ROOT_DIR/build/pcsx-rearmed-bubble-probe"
BUILD_ROOT="$ROOT_DIR/build/pcsx-rearmed-bubble-kmsdrm"
SDL12_ROOT="$ROOT_DIR/build/pcsx-sdl12-compat-bubble-probe"
PCSX_PATCH="$ROOT_DIR/package/standalone-bubble/patches/pcsx-rearmed-bubble-kmsdrm.patch"
PCSX_BATCH_PATCH="$ROOT_DIR/package/standalone-bubble/patches/pcsx-rearmed-bubble-gles-ordered-batch.patch"
PICOFE_PATCH="$ROOT_DIR/package/standalone-bubble/patches/libpicofe-bubble-kmsdrm.patch"
PCSX_REPO="https://github.com/notaz/pcsx_rearmed.git"
SDL12_REPO="https://github.com/libsdl-org/sdl12-compat.git"
PCSX_REF="9f8b6f248e073f03c530efda7c4cc60a7e2ecafc"
PICOFE_REF="dd11f2d723162eb1cf8e6db9f40de7db0d0b6bba"
SDL12_REF="fc2ec0c128197f1f5050e48359bc41e618f3abfb"
JOBS="${JOBS:-$(nproc)}"

for command_name in cmake file git make patch sha256sum; do
    command -v "$command_name" >/dev/null || {
        printf 'error: missing PCSX build command: %s\n' "$command_name" >&2
        exit 1
    }
done
for patch_file in "$PCSX_PATCH" "$PCSX_BATCH_PATCH" "$PICOFE_PATCH"; do
    [ -s "$patch_file" ] || {
        printf 'error: missing PCSX patch: %s\n' "$patch_file" >&2
        exit 1
    }
done

if [ ! -d "$SOURCE_ROOT/.git" ]; then
    [ ! -e "$SOURCE_ROOT" ] || {
        printf 'error: PCSX source path is not a Git clone: %s\n' "$SOURCE_ROOT" >&2
        exit 1
    }
    mkdir -p "$(dirname "$SOURCE_ROOT")"
    git clone --filter=blob:none "$PCSX_REPO" "$SOURCE_ROOT"
fi
git -C "$SOURCE_ROOT" fetch --depth 1 origin "$PCSX_REF"
git -C "$SOURCE_ROOT" reset --hard FETCH_HEAD
git -C "$SOURCE_ROOT" clean -ffdx
git -C "$SOURCE_ROOT" submodule update --init frontend/libpicofe
[ "$(git -C "$SOURCE_ROOT" rev-parse HEAD)" = "$PCSX_REF" ]
[ "$(git -C "$SOURCE_ROOT/frontend/libpicofe" rev-parse HEAD)" = "$PICOFE_REF" ]

if [ ! -d "$SDL12_ROOT/.git" ]; then
    [ ! -e "$SDL12_ROOT" ] || {
        printf 'error: SDL12 source path is not a Git clone: %s\n' "$SDL12_ROOT" >&2
        exit 1
    }
    git clone --filter=blob:none "$SDL12_REPO" "$SDL12_ROOT"
fi
git -C "$SDL12_ROOT" fetch --depth 1 origin "$SDL12_REF"
git -C "$SDL12_ROOT" reset --hard FETCH_HEAD
git -C "$SDL12_ROOT" clean -ffdx
cmake -S "$SDL12_ROOT" -B "$SDL12_ROOT/build-bubble" \
    -DCMAKE_BUILD_TYPE=Release -DSDL12TESTS=OFF \
    -DCMAKE_INSTALL_PREFIX="$SDL12_ROOT/install-bubble"
cmake --build "$SDL12_ROOT/build-bubble" -j"$JOBS"
cmake --install "$SDL12_ROOT/build-bubble"

if [ -e "$BUILD_ROOT" ]; then
    git -C "$SOURCE_ROOT" worktree remove --force "$BUILD_ROOT" 2>/dev/null || true
    find "$BUILD_ROOT" -depth -delete 2>/dev/null || true
fi
git -C "$SOURCE_ROOT" worktree add --detach "$BUILD_ROOT" "$PCSX_REF"
git -C "$BUILD_ROOT" submodule update --init frontend/libpicofe
git -C "$BUILD_ROOT" apply --ignore-space-change --ignore-whitespace "$PCSX_PATCH"
git -C "$BUILD_ROOT" apply --ignore-space-change --ignore-whitespace "$PCSX_BATCH_PATCH"
git -C "$BUILD_ROOT/frontend/libpicofe" apply "$PICOFE_PATCH"

(
    cd "$BUILD_ROOT"
    export SDL_CONFIG="$SDL12_ROOT/install-bubble/bin/sdl-config"
    ./configure \
        --platform=generic \
        --gpu=neon \
        --sound-drivers='alsa sdl' \
        --enable-neon \
        --enable-threads \
        --enable-dynamic \
        --dynarec=ari64
    make clean
    make -j"$JOBS"
    make -C plugins/gpu-gles -j"$JOBS"
)

file "$BUILD_ROOT/pcsx" | grep -q 'ELF 64-bit.*ARM aarch64'
file "$BUILD_ROOT/plugins/gpu-gles/gpu_gles.so" | grep -q 'ELF 64-bit.*ARM aarch64'
sha256sum "$BUILD_ROOT/pcsx" "$BUILD_ROOT/plugins/gpu-gles/gpu_gles.so"
