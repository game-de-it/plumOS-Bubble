#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BUILD_ROOT="$ROOT_DIR/output/build/openbor-bubble"
SOURCE_ROOT="$BUILD_ROOT/source"
OUT_ROOT="$ROOT_DIR/${PLUMOS_BUBBLE_OPENBOR_OUT:-output/openbor/bubble}"
OPENBOR_REPO="${PLUMOS_BUBBLE_OPENBOR_REPO:-https://github.com/DCurrent/openbor.git}"
OPENBOR_REF="494708eb34e71d1afda237873907701c4ec3a569"
PATCH_FILE="$ROOT_DIR/package/standalone-bubble/patches/openbor/openbor-v6391-bubble.patch"
source "$ROOT_DIR/scripts/lib/copy-elf-runtime-deps.sh"
JOBS="${JOBS:-$(nproc)}"
COMMON_FLAGS="-O3 -pipe -march=armv8-a+crc+simd -mtune=cortex-a55 -fcommon"

for command_name in git make patch readelf sha256sum; do
    command -v "$command_name" >/dev/null || {
        printf 'error: missing OpenBOR build command: %s\n' "$command_name" >&2
        exit 1
    }
done
[ -s "$PATCH_FILE" ] || {
    printf 'error: missing OpenBOR Bubble patch: %s\n' "$PATCH_FILE" >&2
    exit 1
}

if [ ! -d "$SOURCE_ROOT/.git" ]; then
    [ ! -e "$SOURCE_ROOT" ] || {
        printf 'error: OpenBOR source path is not a Git clone: %s\n' \
            "$SOURCE_ROOT" >&2
        exit 1
    }
    mkdir -p "$BUILD_ROOT"
    git clone --filter=blob:none "$OPENBOR_REPO" "$SOURCE_ROOT"
fi
git -C "$SOURCE_ROOT" fetch --depth 1 origin "$OPENBOR_REF"
git -C "$SOURCE_ROOT" checkout --detach FETCH_HEAD
git -C "$SOURCE_ROOT" reset --hard FETCH_HEAD
[ "$(git -C "$SOURCE_ROOT" rev-parse HEAD)" = "$OPENBOR_REF" ] || {
    printf 'error: unexpected OpenBOR source ref\n' >&2
    exit 1
}
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git -C "$SOURCE_ROOT" show -s --format=%ct HEAD)}"
export SOURCE_DATE_EPOCH
git -C "$SOURCE_ROOT" apply --check "$PATCH_FILE"
git -C "$SOURCE_ROOT" apply "$PATCH_FILE"

restore_source() {
    git -C "$SOURCE_ROOT" reset --hard "$OPENBOR_REF" >/dev/null 2>&1 || true
}
trap restore_source EXIT

(
    cd "$SOURCE_ROOT/engine"
    make clean BUILD_LINUX=1 >/dev/null 2>&1 || true
    make -j"$JOBS" \
        BUILD_LINUX=1 \
        BUILD_MMX= \
        BUILD_OPENGL= \
        BUILD_LOADGL= \
        BUILD_WEBM= \
        NO_STRIP=1 \
        VERSION_NAME=OpenBOR \
        LNXDEV=/usr/bin \
        PREFIX= \
        GCC_TARGET=aarch64-linux-gnu \
        TARGET_ARCH=aarch64 \
        ARCHFLAGS="$COMMON_FLAGS -DPLUMOS_BUBBLE=1 -Isource/webmlib" \
        LIBRARIES=/usr/lib/aarch64-linux-gnu \
        CC=gcc
)

binary="$SOURCE_ROOT/engine/OpenBOR"
[ -x "$binary" ] || {
    printf 'error: OpenBOR binary was not produced\n' >&2
    exit 1
}
file "$binary" | grep -q 'ELF 64-bit.*ARM aarch64' || {
    printf 'error: OpenBOR output is not AArch64\n' >&2
    exit 1
}

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT/bin" "$OUT_ROOT/lib"
install -m 0755 "$binary" "$OUT_ROOT/bin/OpenBOR"
install -m 0644 "$SOURCE_ROOT/LICENSE" "$OUT_ROOT/LICENSE"
install -m 0644 /usr/share/doc/libsdl2-gfx-1.0-0/copyright \
    "$OUT_ROOT/SDL2-gfx-copyright"

sdl2_gfx="$(readlink -f /usr/lib/aarch64-linux-gnu/libSDL2_gfx-1.0.so.0)"
[ -f "$sdl2_gfx" ] || {
    printf 'error: SDL2_gfx runtime is missing from the toolchain\n' >&2
    exit 1
}
install -m 0644 "$sdl2_gfx" "$OUT_ROOT/lib/libSDL2_gfx-1.0.so.0"
copy_elf_runtime_deps "$OUT_ROOT/lib" "$binary" "$sdl2_gfx"

patch_sha256="$(sha256sum "$PATCH_FILE" | awk '{print $1}')"
cat >"$OUT_ROOT/build-manifest.json" <<EOF
{
  "name": "OpenBOR standalone for plumOS Bubble",
  "source": "$OPENBOR_REPO",
  "source_ref": "$OPENBOR_REF",
  "patch_sha256": "$patch_sha256",
  "target": "aarch64-cortex-a55",
  "video": "package-local-sdl2-kmsdrm",
  "input": "retrogame_joypad"
}
EOF
(
    cd "$OUT_ROOT"
    find bin lib LICENSE SDL2-gfx-copyright build-manifest.json \
        -type f -print |
        sort |
        while IFS= read -r path; do sha256sum "$path"; done
) >"$OUT_ROOT/checksums.sha256"
(
    cd "$OUT_ROOT"
    sha256sum -c checksums.sha256
)
printf 'created: %s\n' "$OUT_ROOT"
