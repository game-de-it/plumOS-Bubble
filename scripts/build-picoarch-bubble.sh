#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TOOLS_IMAGE="${PLUMOS_BUBBLE_PICOARCH_TOOLS_IMAGE:-plumos-v90s-toolchain:dev}"
if [[ ${1:-} != --inside ]]; then
    docker image inspect "$TOOLS_IMAGE" >/dev/null 2>&1 || {
        printf 'error: PicoArch toolchain image is missing: %s\n' "$TOOLS_IMAGE" >&2
        exit 1
    }
    exec docker run --rm --platform linux/arm64 \
        -e SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-}" \
        -v "$ROOT_DIR:/work" -w /work "$TOOLS_IMAGE" \
        ./scripts/build-picoarch-bubble.sh --inside
fi

V90S_REPO="https://github.com/game-de-it/plumOS-V90S_V2.git"
V90S_REF="bc49dafe782173f35ab557035fa96ba81564038d"
WORK_ROOT="$ROOT_DIR/${PLUMOS_BUBBLE_PICOARCH_WORK:-output/build/picoarch-bubble}"
VENDOR_ROOT="$WORK_ROOT/plumOS-V90S"
OUT_ROOT="$ROOT_DIR/${PLUMOS_BUBBLE_PICOARCH_OUT:-output/picoarch/bubble}"
PLUMOS_DIR="$OUT_ROOT/plumos"
V90S_BUILD_SCRIPT="$VENDOR_ROOT/docker/plumos-v90s-toolchain/scripts/build-picoarch.sh"
BUBBLE_AUDIO_STATUS_PATCH="$ROOT_DIR/package/picoarch-bubble/patches/picoarch-bubble-audio-buffer-status.patch"
BUBBLE_RGB565_BYTESWAP_PATCH="$ROOT_DIR/package/picoarch-bubble/patches/picoarch-bubble-rgb565-byteswap.patch"
BUBBLE_VFS_SEEK_PATCH="$ROOT_DIR/package/picoarch-bubble/patches/picoarch-bubble-vfs-seek-status.patch"
BUBBLE_PHYSICAL_INPUT_PATCH="$ROOT_DIR/package/picoarch-bubble/patches/picoarch-bubble-physical-input.patch"
BUBBLE_EVDEV_HOTPLUG_PATCH="$ROOT_DIR/package/picoarch-bubble/patches/picoarch-bubble-evdev-hotplug.patch"
BUBBLE_FBDEV_STAGED_COPY_PATCH="$ROOT_DIR/package/picoarch-bubble/patches/picoarch-bubble-fbdev-staged-copy.patch"
BUBBLE_FBDEV_RENDERER_HEADER="$ROOT_DIR/src/frontend/plumos_fbdev_renderer.h"
BUBBLE_PICOARCH_LAUNCHER="$ROOT_DIR/package/picoarch-bubble/plumos/bin/plumos-picoarch-launch"
SDL_VERSION="2.32.0"
SDL_SHA256="f5c2b52498785858f3de1e2996eba3c1b805d08fe168a47ea527c7fc339072d0"
SDL_ARCHIVE="$ROOT_DIR/build/downloads/SDL2-$SDL_VERSION.tar.gz"
SDL_BUILD_ROOT="$WORK_ROOT/sdl2-minimal"
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-0}"

[ -f "$BUBBLE_AUDIO_STATUS_PATCH" ] || {
    printf 'error: missing Bubble PicoArch patch: %s\n' "$BUBBLE_AUDIO_STATUS_PATCH" >&2
    exit 1
}
[ -f "$BUBBLE_RGB565_BYTESWAP_PATCH" ] || {
    printf 'error: missing Bubble PicoArch patch: %s\n' "$BUBBLE_RGB565_BYTESWAP_PATCH" >&2
    exit 1
}
[ -f "$BUBBLE_VFS_SEEK_PATCH" ] || {
    printf 'error: missing Bubble PicoArch patch: %s\n' "$BUBBLE_VFS_SEEK_PATCH" >&2
    exit 1
}
[ -f "$BUBBLE_PHYSICAL_INPUT_PATCH" ] || {
    printf 'error: missing Bubble PicoArch patch: %s\n' "$BUBBLE_PHYSICAL_INPUT_PATCH" >&2
    exit 1
}
[ -f "$BUBBLE_EVDEV_HOTPLUG_PATCH" ] || {
    printf 'error: missing Bubble PicoArch patch: %s\n' "$BUBBLE_EVDEV_HOTPLUG_PATCH" >&2
    exit 1
}
[ -f "$BUBBLE_FBDEV_STAGED_COPY_PATCH" ] || {
    printf 'error: missing Bubble PicoArch patch: %s\n' "$BUBBLE_FBDEV_STAGED_COPY_PATCH" >&2
    exit 1
}
[ -f "$BUBBLE_FBDEV_RENDERER_HEADER" ] || {
    printf 'error: missing Bubble DRM page-flip renderer: %s\n' "$BUBBLE_FBDEV_RENDERER_HEADER" >&2
    exit 1
}
[ -x "$BUBBLE_PICOARCH_LAUNCHER" ] || {
    printf 'error: missing Bubble PicoArch launcher: %s\n' "$BUBBLE_PICOARCH_LAUNCHER" >&2
    exit 1
}
export PLUMOS_BUBBLE_PICOARCH_AUDIO_STATUS_PATCH="$BUBBLE_AUDIO_STATUS_PATCH"
export PLUMOS_BUBBLE_PICOARCH_RGB565_BYTESWAP_PATCH="$BUBBLE_RGB565_BYTESWAP_PATCH"
export PLUMOS_BUBBLE_PICOARCH_VFS_SEEK_PATCH="$BUBBLE_VFS_SEEK_PATCH"
export PLUMOS_BUBBLE_PICOARCH_PHYSICAL_INPUT_PATCH="$BUBBLE_PHYSICAL_INPUT_PATCH"
export PLUMOS_BUBBLE_PICOARCH_EVDEV_HOTPLUG_PATCH="$BUBBLE_EVDEV_HOTPLUG_PATCH"
export PLUMOS_BUBBLE_PICOARCH_FBDEV_STAGED_COPY_PATCH="$BUBBLE_FBDEV_STAGED_COPY_PATCH"
export PLUMOS_BUBBLE_FBDEV_RENDERER_HEADER="$BUBBLE_FBDEV_RENDERER_HEADER"
BUBBLE_AUDIO_STATUS_PATCH_SHA256="$(sha256sum "$BUBBLE_AUDIO_STATUS_PATCH" | awk '{print $1}')"
BUBBLE_RGB565_BYTESWAP_PATCH_SHA256="$(sha256sum "$BUBBLE_RGB565_BYTESWAP_PATCH" | awk '{print $1}')"
BUBBLE_VFS_SEEK_PATCH_SHA256="$(sha256sum "$BUBBLE_VFS_SEEK_PATCH" | awk '{print $1}')"
BUBBLE_PHYSICAL_INPUT_PATCH_SHA256="$(sha256sum "$BUBBLE_PHYSICAL_INPUT_PATCH" | awk '{print $1}')"
BUBBLE_EVDEV_HOTPLUG_PATCH_SHA256="$(sha256sum "$BUBBLE_EVDEV_HOTPLUG_PATCH" | awk '{print $1}')"
BUBBLE_FBDEV_STAGED_COPY_PATCH_SHA256="$(sha256sum "$BUBBLE_FBDEV_STAGED_COPY_PATCH" | awk '{print $1}')"
BUBBLE_PICOARCH_LAUNCHER_SHA256="$(sha256sum "$BUBBLE_PICOARCH_LAUNCHER" | awk '{print $1}')"

if [ ! -d "$VENDOR_ROOT/.git" ]; then
    rm -rf "$VENDOR_ROOT"
    git clone --filter=blob:none "$V90S_REPO" "$VENDOR_ROOT"
fi
git -C "$VENDOR_ROOT" fetch --depth 1 origin "$V90S_REF"
git -C "$VENDOR_ROOT" reset --hard FETCH_HEAD
git -C "$VENDOR_ROOT" clean -ffdx

# The upstream V90S builder is itself pinned. Run it against the checked-out
# tree, then republish the result as an independent Bubble component.
BUILD_COPY="$WORK_ROOT/build-picoarch-v90s-for-bubble.sh"
sed "s|^ROOT=/workspace$|ROOT=$VENDOR_ROOT|" "$V90S_BUILD_SCRIPT" >"$BUILD_COPY"
python3 - "$BUILD_COPY" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
marker = '''git -C "$SRC" apply \\
  "$ROOT/docker/plumos-v90s-toolchain/picoarch/picoarch-v90s-input-aspect.patch"
'''
addition = marker + r'''
# libretro VFS seek follows fseek semantics: zero on success, -1 on failure.
git -C "$SRC" apply "$PLUMOS_BUBBLE_PICOARCH_VFS_SEEK_PATCH"

# The SDL audio ring is consumed immediately and cannot predict underruns.
# Do not advertise a callback that traps auto-frameskip cores in black output.
git -C "$SRC" apply "$PLUMOS_BUBBLE_PICOARCH_AUDIO_STATUS_PATCH"

# Add Bubble BTN_DPAD button codes while retaining V90S keyboard/HAT mappings.
perl -0pi -e '
  s/(\t\{ KEY_UP,\s+IN_BINDTYPE_PLAYER12,[^\n]+\n)/$1\t{ BTN_DPAD_UP,   IN_BINDTYPE_PLAYER12, RETRO_DEVICE_ID_JOYPAD_UP },\n/;
  s/(\t\{ KEY_DOWN,\s+IN_BINDTYPE_PLAYER12,[^\n]+\n)/$1\t{ BTN_DPAD_DOWN, IN_BINDTYPE_PLAYER12, RETRO_DEVICE_ID_JOYPAD_DOWN },\n/;
  s/(\t\{ KEY_LEFT,\s+IN_BINDTYPE_PLAYER12,[^\n]+\n)/$1\t{ BTN_DPAD_LEFT, IN_BINDTYPE_PLAYER12, RETRO_DEVICE_ID_JOYPAD_LEFT },\n/;
  s/(\t\{ KEY_RIGHT,\s+IN_BINDTYPE_PLAYER12,[^\n]+\n)/$1\t{ BTN_DPAD_RIGHT, IN_BINDTYPE_PLAYER12, RETRO_DEVICE_ID_JOYPAD_RIGHT },\n/;
  s/(\t\{ KEY_UP,\s+PBTN_UP \},\n)/$1\t{ BTN_DPAD_UP, PBTN_UP },\n/;
  s/(\t\{ KEY_DOWN,\s+PBTN_DOWN \},\n)/$1\t{ BTN_DPAD_DOWN, PBTN_DOWN },\n/;
  s/(\t\{ KEY_LEFT,\s+PBTN_LEFT \},\n)/$1\t{ BTN_DPAD_LEFT, PBTN_LEFT },\n/;
  s/(\t\{ KEY_RIGHT,\s+PBTN_RIGHT \},\n)/$1\t{ BTN_DPAD_RIGHT, PBTN_RIGHT },\n/;
' "$SRC/plat_linux.c"

# Apply the physical-label contract captured from Bubble event2. L2/R2 are
# digital BTN_TL2/BTN_TR2 keys; both sticks expose normal X/Y and RX/RY axes.
git -C "$SRC" apply "$PLUMOS_BUBBLE_PICOARCH_PHYSICAL_INPUT_PATCH"

# A removable USB DAC may expose a Consumer Control evdev node. If it is
# unplugged during gameplay, retire that node once instead of polling ENODEV
# forever and starving the emulation/render thread.
git -C "$SRC" apply "$PLUMOS_BUBBLE_PICOARCH_EVDEV_HOTPLUG_PATCH"
'''
if marker not in text:
    raise SystemExit("input patch marker missing")
text = text.replace(marker, addition, 1)
audio_rate_marker = '''git -C "$SRC" apply --recount --unidiff-zero \\
  "$ROOT/docker/plumos-v90s-toolchain/picoarch/picoarch-v90s-display-audio-rate.patch"
'''
audio_rate_addition = audio_rate_marker + r'''
# Affected Mednafen RGB565 frames need a launcher-scoped byte-order correction
# before the Bubble fbdev presenter expands them to BGRA8888.
git -C "$SRC" apply "$PLUMOS_BUBBLE_PICOARCH_RGB565_BYTESWAP_PATCH"

# Bubble exposes only one 640x480 fbdev scanout page. Convert into a RAM frame,
# then perform one short nonblocking copy instead of writing scanlines
# directly into the visible page. FBIO_WAITFORVSYNC is not usable on Bubble's
# Rockchip DRM fbdev helper because it repeatedly times out in the kernel.
git -C "$SRC" apply --recount "$PLUMOS_BUBBLE_PICOARCH_FBDEV_STAGED_COPY_PATCH"
cp "$PLUMOS_BUBBLE_FBDEV_RENDERER_HEADER" "$SRC/plumos_fbdev_renderer.h"
perl -0pi -e '
  s{(CFLAGS\s+\+= -I\./ -I\./libretro-common/include/)}{$1 -I/usr/include/libdrm};
  s{(LDFLAGS\s+=.*?)(\n)}{$1 -ldrm$2};
' "$SRC/Makefile"
'''
if audio_rate_marker not in text:
    raise SystemExit("display audio rate patch marker missing")
path.write_text(text.replace(audio_rate_marker, audio_rate_addition, 1))
PY
bash "$BUILD_COPY"

mkdir -p "$(dirname "$SDL_ARCHIVE")"
if [ ! -r "$SDL_ARCHIVE" ] ||
   ! printf '%s  %s\n' "$SDL_SHA256" "$SDL_ARCHIVE" | sha256sum -c - >/dev/null 2>&1; then
    curl -LfsS \
        "https://github.com/libsdl-org/SDL/releases/download/release-$SDL_VERSION/SDL2-$SDL_VERSION.tar.gz" \
        -o "$SDL_ARCHIVE"
fi
printf '%s  %s\n' "$SDL_SHA256" "$SDL_ARCHIVE" | sha256sum -c -
rm -rf "$SDL_BUILD_ROOT"
mkdir -p "$SDL_BUILD_ROOT/source" "$SDL_BUILD_ROOT/build" "$SDL_BUILD_ROOT/stage"
tar -C "$SDL_BUILD_ROOT/source" --strip-components=1 -xf "$SDL_ARCHIVE"
(
    cd "$SDL_BUILD_ROOT/build"
    "$SDL_BUILD_ROOT/source/configure" \
        --prefix=/usr \
        --disable-video-x11 \
        --disable-video-wayland \
        --disable-video-opengl \
        --disable-video-opengles \
        --disable-video-vulkan \
        --disable-video-kmsdrm \
        --enable-alsa \
        --disable-pulseaudio \
        --disable-jack \
        --disable-sndio \
        --disable-static \
        --enable-shared
    make -j"${JOBS:-$(nproc)}"
    make DESTDIR="$SDL_BUILD_ROOT/stage" install
)
SDL_LIBRARY="$(find "$SDL_BUILD_ROOT/stage/usr/lib" -type f \
    -name 'libSDL2-2.0.so.*' -print | sort | tail -n 1)"
[ -n "$SDL_LIBRARY" ] || {
    printf 'error: minimal SDL2 build did not produce a shared library\n' >&2
    exit 1
}
SDL_NEEDED="$(readelf -d "$SDL_LIBRARY" | awk -F'[][]' '/NEEDED/ { print $2 }' | sort)"
for allowed in libasound.so.2 libc.so.6 ld-linux-aarch64.so.1 libm.so.6; do
    SDL_NEEDED="$(printf '%s\n' "$SDL_NEEDED" | grep -Fvx "$allowed" || true)"
done
[ -z "$SDL_NEEDED" ] || {
    printf 'error: minimal SDL2 has unexpected runtime dependencies:\n%s\n' "$SDL_NEEDED" >&2
    exit 1
}

V90S_OUT="$VENDOR_ROOT/output/picoarch/v90s"
[ -x "$V90S_OUT/picoarch/bin/picoarch" ] || {
    printf 'error: PicoArch build did not produce a binary\n' >&2
    exit 1
}

rm -rf "$OUT_ROOT"
mkdir -p "$PLUMOS_DIR/picoarch/bin" "$PLUMOS_DIR/picoarch/lib" \
    "$PLUMOS_DIR/bin" "$PLUMOS_DIR/components/picoarch" "$PLUMOS_DIR/licenses" \
    "$PLUMOS_DIR/factory-defaults/picoarch/config/standalone"
install -m 0755 "$V90S_OUT/picoarch/bin/picoarch" \
    "$PLUMOS_DIR/picoarch/bin/picoarch"
install -m 0644 "$V90S_OUT"/picoarch/lib/* "$PLUMOS_DIR/picoarch/lib/"
install -m 0644 "$SDL_LIBRARY" \
    "$PLUMOS_DIR/picoarch/lib/libSDL2-2.0.so.0"
strip --strip-unneeded "$PLUMOS_DIR/picoarch/lib/libSDL2-2.0.so.0"
install -m 0755 \
    "$BUBBLE_PICOARCH_LAUNCHER" \
    "$PLUMOS_DIR/bin/plumos-picoarch-launch"
install -m 0644 \
    "$ROOT_DIR/package/picoarch-bubble/plumos/factory-defaults/picoarch/config/standalone/picoarch.env" \
    "$PLUMOS_DIR/factory-defaults/picoarch/config/standalone/picoarch.env"
install -m 0644 "$V90S_OUT/licenses/picoarch-LICENSE" \
    "$PLUMOS_DIR/licenses/picoarch-LICENSE"
install -m 0644 "$V90S_OUT/licenses/sdl12-compat-LICENSE.txt" \
    "$PLUMOS_DIR/licenses/picoarch-sdl12-compat-LICENSE"
install -m 0644 "$SDL_BUILD_ROOT/source/LICENSE.txt" \
    "$PLUMOS_DIR/licenses/picoarch-SDL2-LICENSE.txt"

cat >"$PLUMOS_DIR/components/picoarch/manifest.json" <<EOF
{
  "name": "plumOS Bubble PicoArch",
  "device": "bubble",
  "source_ref": "picoarch:802047c276a5a931b0bf837c4ea4b8e238bdeabe v90s-build:$V90S_REF sdl2:$SDL_VERSION:$SDL_SHA256 bubble-audio-status:$BUBBLE_AUDIO_STATUS_PATCH_SHA256 bubble-rgb565-byteswap:$BUBBLE_RGB565_BYTESWAP_PATCH_SHA256 bubble-vfs-seek:$BUBBLE_VFS_SEEK_PATCH_SHA256 bubble-physical-input:$BUBBLE_PHYSICAL_INPUT_PATCH_SHA256 bubble-evdev-hotplug:$BUBBLE_EVDEV_HOTPLUG_PATCH_SHA256 bubble-fbdev-staged-copy:$BUBBLE_FBDEV_STAGED_COPY_PATCH_SHA256 bubble-launcher:$BUBBLE_PICOARCH_LAUNCHER_SHA256",
  "render_contract": "cpu-drm-pageflip-rgb565-to-bgra8888 with per-core RGB565 byte-order correction and staged-fbdev fallback",
  "input_contract": "plumOS Bubble Controller physical labels, digital L2/R2, dual analog, L3/R3 and F1/F2 menu",
  "core_route": "cores/*_libretro.so"
}
EOF

(
    cd "$PLUMOS_DIR"
    find bin picoarch licenses factory-defaults/picoarch components/picoarch -type f \
        ! -path 'components/picoarch/checksums.sha256' \
        -print |
        sort |
        while IFS= read -r path; do sha256sum "$path"; done
) >"$PLUMOS_DIR/components/picoarch/checksums.sha256"
(
    cd "$PLUMOS_DIR"
    sha256sum -c components/picoarch/checksums.sha256
)
printf 'created: %s\n' "$OUT_ROOT"
