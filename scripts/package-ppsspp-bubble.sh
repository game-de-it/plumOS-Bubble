#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BINARY="${1:?PPSSPP binary is required}"
SOURCE_DIR="${2:?PPSSPP source directory is required}"
OUT_ROOT="$ROOT_DIR/${PLUMOS_BUBBLE_PPSSPP_OUT:-output/ppsspp/bubble}"
PATCH_FILE="$ROOT_DIR/package/standalone-bubble/patches/ppsspp/ppsspp-1.20.4-bubble-no-sdl2-ttf.patch"
source "$ROOT_DIR/scripts/lib/copy-elf-runtime-deps.sh"
PPSSPP_REPO="${PLUMOS_BUBBLE_PPSSPP_REPO:-https://github.com/hrydgard/ppsspp.git}"
PPSSPP_REF="${PLUMOS_BUBBLE_PPSSPP_REF:-v1.20.4}"
PPSSPP_COMMIT="fa50bb1976065c4f8b1b47af227d367fe9771555"
COMMON_FLAGS="${PLUMOS_BUBBLE_PPSSPP_COMPILER_FLAGS:--O3 -mcpu=cortex-a55 -mtune=cortex-a55 -fomit-frame-pointer}"
ARTIFACT_ORIGIN="${PLUMOS_BUBBLE_PPSSPP_ARTIFACT_ORIGIN:-source-built in the plumOS Bubble ARM64 toolchain}"
SOURCE_PATCHES="${PLUMOS_BUBBLE_PPSSPP_SOURCE_PATCHES:-ppsspp-1.20.4-bubble-no-sdl2-ttf.patch}"
READELF="${READELF:-$(command -v readelf || command -v llvm-readelf || true)}"

[ -x "$BINARY" ]
[ -d "$SOURCE_DIR/assets" ]
[ -s "$SOURCE_DIR/LICENSE.TXT" ]
[ -s "$PATCH_FILE" ]
[ -n "$READELF" ]
[ "$(git -C "$SOURCE_DIR" rev-parse HEAD)" = "$PPSSPP_COMMIT" ]
file "$BINARY" | grep -q 'ELF 64-bit.*ARM aarch64'

needed="$("$READELF" -d "$BINARY" | awk -F'[][]' '/NEEDED/ { print $2 }')"
for library in libSDL2-2.0.so.0 libGLESv2.so.2 libEGL.so.1; do
    grep -qx "$library" <<<"$needed" || {
        printf 'error: PPSSPP dependency missing: %s\n' "$library" >&2
        exit 1
    }
done
if grep -Eq '^lib(X11|Xext|vulkan)' <<<"$needed"; then
    printf 'error: PPSSPP contains an unintended desktop dependency\n' >&2
    exit 1
fi

rm -rf "$OUT_ROOT"
mkdir -p "$OUT_ROOT/runtime/bin" "$OUT_ROOT/runtime/assets" \
    "$OUT_ROOT/runtime/lib"
install -m 0755 "$BINARY" "$OUT_ROOT/runtime/bin/PPSSPPSDL"
copy_elf_runtime_deps "$OUT_ROOT/runtime/lib" "$BINARY"
rsync -a --delete "$SOURCE_DIR/assets/" "$OUT_ROOT/runtime/assets/"
install -m 0644 "$SOURCE_DIR/LICENSE.TXT" "$OUT_ROOT/LICENSE.txt"

binary_sha256="$(sha256sum "$OUT_ROOT/runtime/bin/PPSSPPSDL" |
    awk '{ print $1 }')"
asset_tree_sha256="$(
    cd "$OUT_ROOT/runtime"
    find assets -type f -print0 |
        sort -z |
        xargs -0 sha256sum |
        sha256sum |
        awk '{ print $1 }'
)"
patch_sha256="$(sha256sum "$PATCH_FILE" | awk '{ print $1 }')"
cat >"$OUT_ROOT/build-manifest.json" <<EOF
{
  "name": "PPSSPP for plumOS Bubble",
  "upstream": "$PPSSPP_REPO",
  "ref": "$PPSSPP_REF",
  "commit": "$PPSSPP_COMMIT",
  "binary_sha256": "$binary_sha256",
  "asset_tree_sha256": "$asset_tree_sha256",
  "bubble_patch_sha256": "$patch_sha256",
  "source_patches": "$SOURCE_PATCHES",
  "target_cpu": "cortex-a55",
  "compiler_flags": "$COMMON_FLAGS",
  "renderer": "Bubble Mali-G52 KMSDRM GLES2",
  "artifact_origin": "$ARTIFACT_ORIGIN"
}
EOF
(
    cd "$OUT_ROOT"
    find runtime LICENSE.txt build-manifest.json -type f -print |
        sort |
        while IFS= read -r path; do sha256sum "$path"; done
) >"$OUT_ROOT/checksums.sha256"
(
    cd "$OUT_ROOT"
    sha256sum -c checksums.sha256
)
printf 'created: %s\n' "$OUT_ROOT"
