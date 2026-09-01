#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
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
BUBBLE_TRIGGER_AXES_PATCH="$ROOT_DIR/package/picoarch-bubble/patches/picoarch-bubble-trigger-axes.patch"
BUBBLE_EVDEV_HOTPLUG_PATCH="$ROOT_DIR/package/picoarch-bubble/patches/picoarch-bubble-evdev-hotplug.patch"
BUBBLE_FBDEV_STAGED_COPY_PATCH="$ROOT_DIR/package/picoarch-bubble/patches/picoarch-bubble-fbdev-staged-copy.patch"
BUBBLE_FBDEV_RENDERER_HEADER="$ROOT_DIR/src/frontend/plumos_fbdev_renderer.h"
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
[ -f "$BUBBLE_TRIGGER_AXES_PATCH" ] || {
    printf 'error: missing Bubble PicoArch patch: %s\n' "$BUBBLE_TRIGGER_AXES_PATCH" >&2
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
export PLUMOS_BUBBLE_PICOARCH_AUDIO_STATUS_PATCH="$BUBBLE_AUDIO_STATUS_PATCH"
export PLUMOS_BUBBLE_PICOARCH_RGB565_BYTESWAP_PATCH="$BUBBLE_RGB565_BYTESWAP_PATCH"
export PLUMOS_BUBBLE_PICOARCH_VFS_SEEK_PATCH="$BUBBLE_VFS_SEEK_PATCH"
export PLUMOS_BUBBLE_PICOARCH_TRIGGER_AXES_PATCH="$BUBBLE_TRIGGER_AXES_PATCH"
export PLUMOS_BUBBLE_PICOARCH_EVDEV_HOTPLUG_PATCH="$BUBBLE_EVDEV_HOTPLUG_PATCH"
export PLUMOS_BUBBLE_PICOARCH_FBDEV_STAGED_COPY_PATCH="$BUBBLE_FBDEV_STAGED_COPY_PATCH"
export PLUMOS_BUBBLE_FBDEV_RENDERER_HEADER="$BUBBLE_FBDEV_RENDERER_HEADER"
BUBBLE_AUDIO_STATUS_PATCH_SHA256="$(sha256sum "$BUBBLE_AUDIO_STATUS_PATCH" | awk '{print $1}')"
BUBBLE_RGB565_BYTESWAP_PATCH_SHA256="$(sha256sum "$BUBBLE_RGB565_BYTESWAP_PATCH" | awk '{print $1}')"
BUBBLE_VFS_SEEK_PATCH_SHA256="$(sha256sum "$BUBBLE_VFS_SEEK_PATCH" | awk '{print $1}')"
BUBBLE_TRIGGER_AXES_PATCH_SHA256="$(sha256sum "$BUBBLE_TRIGGER_AXES_PATCH" | awk '{print $1}')"
BUBBLE_EVDEV_HOTPLUG_PATCH_SHA256="$(sha256sum "$BUBBLE_EVDEV_HOTPLUG_PATCH" | awk '{print $1}')"
BUBBLE_FBDEV_STAGED_COPY_PATCH_SHA256="$(sha256sum "$BUBBLE_FBDEV_STAGED_COPY_PATCH" | awk '{print $1}')"

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

# Bubble publishes L2/R2 as ABS_Z/ABS_RZ trigger axes. Expose them through the
# existing BTN_TL2/BTN_TR2 bind slots for both gameplay and binding capture.
git -C "$SRC" apply "$PLUMOS_BUBBLE_PICOARCH_TRIGGER_AXES_PATCH"

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

V90S_OUT="$VENDOR_ROOT/output/picoarch/v90s"
[ -x "$V90S_OUT/picoarch/bin/picoarch" ] || {
    printf 'error: PicoArch build did not produce a binary\n' >&2
    exit 1
}

rm -rf "$OUT_ROOT"
mkdir -p "$PLUMOS_DIR/picoarch/bin" "$PLUMOS_DIR/picoarch/lib" \
    "$PLUMOS_DIR/bin" "$PLUMOS_DIR/components/picoarch" "$PLUMOS_DIR/licenses"
install -m 0755 "$V90S_OUT/picoarch/bin/picoarch" \
    "$PLUMOS_DIR/picoarch/bin/picoarch"
install -m 0644 "$V90S_OUT"/picoarch/lib/* "$PLUMOS_DIR/picoarch/lib/"
install -m 0755 \
    "$ROOT_DIR/package/picoarch-bubble/plumos/bin/plumos-picoarch-launch" \
    "$PLUMOS_DIR/bin/plumos-picoarch-launch"
install -m 0644 "$V90S_OUT/licenses/picoarch-LICENSE" \
    "$PLUMOS_DIR/licenses/picoarch-LICENSE"
install -m 0644 "$V90S_OUT/licenses/sdl12-compat-LICENSE.txt" \
    "$PLUMOS_DIR/licenses/picoarch-sdl12-compat-LICENSE"

cat >"$PLUMOS_DIR/components/picoarch/manifest.json" <<EOF
{
  "name": "plumOS Bubble PicoArch",
  "device": "bubble",
  "source_ref": "picoarch:802047c276a5a931b0bf837c4ea4b8e238bdeabe v90s-build:$V90S_REF bubble-audio-status:$BUBBLE_AUDIO_STATUS_PATCH_SHA256 bubble-rgb565-byteswap:$BUBBLE_RGB565_BYTESWAP_PATCH_SHA256 bubble-vfs-seek:$BUBBLE_VFS_SEEK_PATCH_SHA256 bubble-trigger-axes:$BUBBLE_TRIGGER_AXES_PATCH_SHA256 bubble-evdev-hotplug:$BUBBLE_EVDEV_HOTPLUG_PATCH_SHA256 bubble-fbdev-staged-copy:$BUBBLE_FBDEV_STAGED_COPY_PATCH_SHA256",
  "render_contract": "cpu-drm-pageflip-rgb565-to-bgra8888 with staged-fbdev fallback",
  "input_contract": "plumOS Bubble Controller evdev BTN_DPAD, ABS_Z/RZ triggers and full gamepad",
  "core_route": "cores/*_libretro.so"
}
EOF

(
    cd "$PLUMOS_DIR"
    find bin picoarch licenses components/picoarch -type f \
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
