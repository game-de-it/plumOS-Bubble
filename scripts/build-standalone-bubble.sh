#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
OUT_ROOT="$ROOT_DIR/${PLUMOS_BUBBLE_STANDALONE_OUT:-output/standalone/bubble}"
PLUMOS_DIR="$OUT_ROOT/plumos"
PACKAGE_ROOT="$ROOT_DIR/package/standalone-bubble/plumos"
PCSX_SOURCE="$ROOT_DIR/build/pcsx-rearmed-bubble-probe"
PCSX_BUILD="$ROOT_DIR/build/pcsx-rearmed-bubble-kmsdrm"
SDL12_BUILD="$ROOT_DIR/build/pcsx-sdl12-compat-bubble-probe/install-bubble/lib"
PCSX_SDL2_BUILD="$ROOT_DIR/build/pyxel-bubble-sdl2"
YABASANSHIRO_BUILD="$ROOT_DIR/${PLUMOS_BUBBLE_YABASANSHIRO_OUT:-output/yabasanshiro/bubble}"
DRASTIC_BUILD="$ROOT_DIR/${PLUMOS_BUBBLE_DRASTIC_OUT:-output/drastic/bubble}"
PPSSPP_BUILD="$ROOT_DIR/${PLUMOS_BUBBLE_PPSSPP_OUT:-output/ppsspp/bubble}"
OPENBOR_BUILD="$ROOT_DIR/${PLUMOS_BUBBLE_OPENBOR_OUT:-output/openbor/bubble}"
VENDOR_GPU_ROOT="$ROOT_DIR/artifacts/vendor/bubble-stock-source/runtime/gpu"
VENDOR_MALI_AARCH64="$VENDOR_GPU_ROOT/libmali-aarch64.so.1.9.0"
VENDOR_MALI_ARMHF="$VENDOR_GPU_ROOT/libmali-armhf.so.1.9.0"
PCSX_REF="9f8b6f248e073f03c530efda7c4cc60a7e2ecafc"
PICOFE_REF="dd11f2d723162eb1cf8e6db9f40de7db0d0b6bba"
SDL12_REF="fc2ec0c128197f1f5050e48359bc41e618f3abfb"
YABASANSHIRO_REF="8406a5c11d7b6186a44c7fe48f493e6de5f8cb18"
DRASTIC_REF="b88e6b75963106c0bd54dfe112f860c6bdbfe593"
PPSSPP_REF="fa50bb1976065c4f8b1b47af227d367fe9771555"
OPENBOR_REF="494708eb34e71d1afda237873907701c4ec3a569"
PCSX_PATCH="$ROOT_DIR/package/standalone-bubble/patches/pcsx-rearmed-bubble-kmsdrm.patch"
PCSX_BATCH_PATCH="$ROOT_DIR/package/standalone-bubble/patches/pcsx-rearmed-bubble-gles-ordered-batch.patch"
PICOFE_PATCH="$ROOT_DIR/package/standalone-bubble/patches/libpicofe-bubble-kmsdrm.patch"
YABASANSHIRO_STANDALONE_PATCH="$ROOT_DIR/package/standalone-bubble/patches/yabasanshiro/yabasanshiro-2.10.4-bubble-standalone.patch"
YABASANSHIRO_FRAMEBUFFER_PATCH="$ROOT_DIR/package/standalone-bubble/patches/yabasanshiro/yabasanshiro-2.10.4-bubble-vdp1-framebuffer-readback.patch"
YABASANSHIRO_READBACK_PATCH="$ROOT_DIR/package/standalone-bubble/patches/yabasanshiro/yabasanshiro-2.10.4-bubble-vdp1-readback.patch"
YABASANSHIRO_INPUT_PATCH="$ROOT_DIR/package/standalone-bubble/patches/yabasanshiro/yabasanshiro-2.10.4-bubble-input.patch"
YABASANSHIRO_SCHED_OTHER_PATCH="$ROOT_DIR/patches/libretro-cores-bubble/yabasanshiro-2.10.4-bubble-sched-other.patch"
DRASTIC_BUILD_PATCH="$ROOT_DIR/package/standalone-bubble/patches/drastic/steward-fu-nds-bubble-toolchain.patch"
DRASTIC_MMAP_COMPAT="$ROOT_DIR/package/standalone-bubble/src/drastic-mmap-compat.c"
PPSSPP_PATCH="$ROOT_DIR/package/standalone-bubble/patches/ppsspp/ppsspp-1.20.4-bubble-no-sdl2-ttf.patch"
OPENBOR_PATCH="$ROOT_DIR/package/standalone-bubble/patches/openbor/openbor-v6391-bubble.patch"

for path in \
    "$PCSX_BUILD/pcsx" \
    "$PCSX_BUILD/plugins/gpu-gles/gpu_gles.so" \
    "$PCSX_BUILD/frontend/pandora/skin/font.png" \
    "$PCSX_BUILD/frontend/pandora/skin/selector.png" \
    "$PCSX_BUILD/frontend/pandora/skin/background.png" \
    "$PCSX_BUILD/frontend/pandora/skin/skin.txt" \
    "$SDL12_BUILD/libSDL-1.2.so.0" \
    "$PCSX_SDL2_BUILD/stage/usr/lib/libSDL2-2.0.so.0" \
    "$PCSX_SDL2_BUILD/source/LICENSE.txt" \
    "$YABASANSHIRO_BUILD/yabasanshiro" \
    "$YABASANSHIRO_BUILD/LICENSE" \
    "$DRASTIC_BUILD/drastic" \
    "$DRASTIC_BUILD/runner" \
    "$DRASTIC_BUILD/runtime/ld-linux-armhf.so.3" \
    "$DRASTIC_BUILD/lib/libSDL2-2.0.so.0" \
    "$DRASTIC_BUILD/lib/libdrastic_mmap_compat.so" \
    "$DRASTIC_BUILD/build-manifest.json" \
    "$DRASTIC_BUILD/checksums.sha256" \
    "$DRASTIC_BUILD/integration-LICENSE" \
    "$DRASTIC_BUILD/upstream-release-readme.txt" \
    "$PPSSPP_BUILD/runtime/bin/PPSSPPSDL" \
    "$PPSSPP_BUILD/runtime/assets" \
    "$PPSSPP_BUILD/LICENSE.txt" \
    "$PPSSPP_BUILD/build-manifest.json" \
    "$PPSSPP_BUILD/checksums.sha256" \
    "$OPENBOR_BUILD/bin/OpenBOR" \
    "$OPENBOR_BUILD/lib/libSDL2_gfx-1.0.so.0" \
    "$OPENBOR_BUILD/LICENSE" \
    "$OPENBOR_BUILD/SDL2-gfx-copyright" \
    "$OPENBOR_BUILD/build-manifest.json" \
    "$OPENBOR_BUILD/checksums.sha256" \
    "$VENDOR_MALI_AARCH64" \
    "$VENDOR_MALI_ARMHF" \
    "$PCSX_PATCH" \
    "$PCSX_BATCH_PATCH" \
    "$PICOFE_PATCH" \
    "$PCSX_BUILD/COPYING" \
    "$ROOT_DIR/build/pcsx-sdl12-compat-bubble-probe/LICENSE.txt" \
    "$YABASANSHIRO_STANDALONE_PATCH" \
    "$YABASANSHIRO_FRAMEBUFFER_PATCH" \
    "$YABASANSHIRO_READBACK_PATCH" \
    "$YABASANSHIRO_INPUT_PATCH" \
    "$YABASANSHIRO_SCHED_OTHER_PATCH" \
    "$DRASTIC_BUILD_PATCH" \
    "$DRASTIC_MMAP_COMPAT" \
    "$PPSSPP_PATCH" \
    "$OPENBOR_PATCH"; do
    [ -e "$path" ] || {
        printf 'error: missing standalone build input: %s\n' "$path" >&2
        exit 1
    }
done

[ "${PLUMOS_BUBBLE_INCLUDE_CAPTURED_VENDOR_GPU:-0}" = 1 ] || {
    printf '%s\n' \
        'error: captured vendor GPU runtime is required for local hardware validation' \
        'set PLUMOS_BUBBLE_INCLUDE_CAPTURED_VENDOR_GPU=1 only for a private development image' \
        'the resulting package is not release eligible' >&2
    exit 1
}

(
    cd "$DRASTIC_BUILD"
    sha256sum -c checksums.sha256
)
(
    cd "$PPSSPP_BUILD"
    sha256sum -c checksums.sha256
)
(
    cd "$OPENBOR_BUILD"
    sha256sum -c checksums.sha256
)

[ "$(git -C "$PCSX_BUILD" rev-parse HEAD)" = "$PCSX_REF" ] || {
    printf 'error: unexpected PCSX-ReARMed source ref\n' >&2
    exit 1
}
[ "$(git -C "$PCSX_SOURCE" rev-parse HEAD)" = "$PCSX_REF" ] || {
    printf 'error: unexpected pristine PCSX-ReARMed source ref\n' >&2
    exit 1
}
[ "$(git -C "$PCSX_BUILD/frontend/libpicofe" rev-parse HEAD)" = \
    "$PICOFE_REF" ] || {
    printf 'error: unexpected libpicofe source ref\n' >&2
    exit 1
}
[ "$(git -C "$ROOT_DIR/build/pcsx-sdl12-compat-bubble-probe" rev-parse HEAD)" = "$SDL12_REF" ] || {
    printf 'error: unexpected sdl12-compat source ref\n' >&2
    exit 1
}
git -C "$PCSX_SOURCE" apply --check --ignore-space-change \
    --ignore-whitespace "$PCSX_PATCH" || {
    printf 'error: PCSX Bubble KMSDRM patch is not reproducible from the pinned source\n' >&2
    exit 1
}
git -C "$PCSX_BUILD" apply --reverse --check --ignore-space-change \
    --ignore-whitespace "$PCSX_BATCH_PATCH" || {
    printf 'error: PCSX Bubble GLES ordered-batch patch is not applied\n' >&2
    exit 1
}
git -C "$PCSX_BUILD/frontend/libpicofe" apply --reverse --check \
    "$PICOFE_PATCH" || {
    printf 'error: libpicofe Bubble KMSDRM patch is not applied\n' >&2
    exit 1
}
PCSX_PATCH_SHA256="$(sha256sum "$PCSX_PATCH" | awk '{ print $1 }')"
PCSX_BATCH_PATCH_SHA256="$(sha256sum "$PCSX_BATCH_PATCH" | awk '{ print $1 }')"
PICOFE_PATCH_SHA256="$(sha256sum "$PICOFE_PATCH" | awk '{ print $1 }')"
YABASANSHIRO_STANDALONE_PATCH_SHA256="$(sha256sum "$YABASANSHIRO_STANDALONE_PATCH" | awk '{ print $1 }')"
YABASANSHIRO_FRAMEBUFFER_PATCH_SHA256="$(sha256sum "$YABASANSHIRO_FRAMEBUFFER_PATCH" | awk '{ print $1 }')"
YABASANSHIRO_READBACK_PATCH_SHA256="$(sha256sum "$YABASANSHIRO_READBACK_PATCH" | awk '{ print $1 }')"
YABASANSHIRO_INPUT_PATCH_SHA256="$(sha256sum "$YABASANSHIRO_INPUT_PATCH" | awk '{ print $1 }')"
YABASANSHIRO_SCHED_OTHER_PATCH_SHA256="$(
    sha256sum "$YABASANSHIRO_SCHED_OTHER_PATCH" | awk '{ print $1 }'
)"
DRASTIC_BUILD_PATCH_SHA256="$(sha256sum "$DRASTIC_BUILD_PATCH" | awk '{ print $1 }')"
DRASTIC_MMAP_COMPAT_SHA256="$(sha256sum "$DRASTIC_MMAP_COMPAT" | awk '{ print $1 }')"
PPSSPP_PATCH_SHA256="$(sha256sum "$PPSSPP_PATCH" | awk '{ print $1 }')"
OPENBOR_PATCH_SHA256="$(sha256sum "$OPENBOR_PATCH" | awk '{ print $1 }')"

rm -rf "$OUT_ROOT"
mkdir -p \
    "$PLUMOS_DIR/emulator/standalone/pcsx_rearmed/plugins" \
    "$PLUMOS_DIR/emulator/standalone/pcsx_rearmed/lib" \
    "$PLUMOS_DIR/emulator/standalone/pcsx_rearmed/skin" \
    "$PLUMOS_DIR/emulator/standalone/yabasanshiro/lib" \
    "$PLUMOS_DIR/emulator/standalone/drastic" \
    "$PLUMOS_DIR/emulator/standalone/drastic/runner-lib" \
    "$PLUMOS_DIR/emulator/standalone/ppsspp" \
    "$PLUMOS_DIR/emulator/standalone/openbor" \
    "$PLUMOS_DIR/emulator/lib" \
    "$PLUMOS_DIR/components/standalone" \
    "$PLUMOS_DIR/licenses"
rsync -a "$PACKAGE_ROOT/" "$PLUMOS_DIR/"
for loader_name in \
    libmali.so.1.9.0 libmali.so.1 libEGL.so.1 libGLESv2.so.2 libgbm.so.1; do
    install -m 0644 "$VENDOR_MALI_AARCH64" \
        "$PLUMOS_DIR/emulator/lib/$loader_name"
done
install -m 0755 "$PCSX_BUILD/pcsx" \
    "$PLUMOS_DIR/emulator/standalone/pcsx_rearmed/pcsx"
install -m 0644 "$PCSX_BUILD/plugins/gpu-gles/gpu_gles.so" \
    "$PLUMOS_DIR/emulator/standalone/pcsx_rearmed/plugins/gpu_gles.so"
install -m 0644 "$SDL12_BUILD/libSDL-1.2.so.0" \
    "$PLUMOS_DIR/emulator/standalone/pcsx_rearmed/lib/libSDL-1.2.so.0"
# sdl12-compat loads SDL2 by SONAME at runtime. Keep the Bubble KMSDRM/ALSA
# build in the same component directory; the generic Debian SDL2 also links
# PulseAudio DSOs that are intentionally absent from the minimal System.
install -m 0644 "$PCSX_SDL2_BUILD/stage/usr/lib/libSDL2-2.0.so.0" \
    "$PLUMOS_DIR/emulator/standalone/pcsx_rearmed/lib/libSDL2-2.0.so.0"
install -m 0644 "$PCSX_BUILD/frontend/pandora/skin/font.png" \
    "$PLUMOS_DIR/emulator/standalone/pcsx_rearmed/skin/fontx2.png"
install -m 0644 "$PCSX_BUILD/frontend/pandora/skin/selector.png" \
    "$PLUMOS_DIR/emulator/standalone/pcsx_rearmed/skin/selectorx2.png"
install -m 0644 "$PCSX_BUILD/frontend/pandora/skin/background.png" \
    "$PLUMOS_DIR/emulator/standalone/pcsx_rearmed/skin/background.png"
install -m 0644 "$PCSX_BUILD/frontend/pandora/skin/skin.txt" \
    "$PLUMOS_DIR/emulator/standalone/pcsx_rearmed/skin/skin.txt"
install -m 0644 "$PCSX_BUILD/COPYING" \
    "$PLUMOS_DIR/licenses/pcsx-rearmed-standalone-COPYING"
install -m 0644 "$ROOT_DIR/build/pcsx-sdl12-compat-bubble-probe/LICENSE.txt" \
    "$PLUMOS_DIR/licenses/sdl12-compat-LICENSE"
install -m 0644 "$PCSX_SDL2_BUILD/source/LICENSE.txt" \
    "$PLUMOS_DIR/licenses/pcsx-sdl2-LICENSE.txt"
install -m 0755 "$YABASANSHIRO_BUILD/yabasanshiro" \
    "$PLUMOS_DIR/emulator/standalone/yabasanshiro/yabasanshiro"
rsync -a "$YABASANSHIRO_BUILD/lib/" \
    "$PLUMOS_DIR/emulator/standalone/yabasanshiro/lib/"
install -m 0644 "$YABASANSHIRO_BUILD/LICENSE" \
    "$PLUMOS_DIR/licenses/yabasanshiro-LICENSE"
rsync -a \
    --exclude='checksums.sha256' \
    --exclude='integration-LICENSE' \
    --exclude='upstream-release-readme.txt' \
    "$DRASTIC_BUILD/" \
    "$PLUMOS_DIR/emulator/standalone/drastic/"
install -m 0644 "$PCSX_SDL2_BUILD/stage/usr/lib/libSDL2-2.0.so.0" \
    "$PLUMOS_DIR/emulator/standalone/drastic/runner-lib/libSDL2-2.0.so.0"
for loader_name in \
    libmali.so.1.9.0 libmali.so.1 libEGL.so.1 libGLESv2.so.2 libgbm.so.1; do
    install -m 0644 "$VENDOR_MALI_ARMHF" \
        "$PLUMOS_DIR/emulator/standalone/drastic/lib/$loader_name"
done
drastic_packaged_config="$PLUMOS_DIR/emulator/standalone/drastic/config/drastic.cfg"
sed \
    's/^controls_b\[CONTROL_INDEX_MENU\] = [0-9][0-9]*$/controls_b[CONTROL_INDEX_MENU] = 1041/' \
    "$drastic_packaged_config" >"$drastic_packaged_config.next"
mv "$drastic_packaged_config.next" "$drastic_packaged_config"
grep -Fqx 'controls_b[CONTROL_INDEX_MENU] = 1041' \
    "$drastic_packaged_config" || {
    printf 'error: DraStic packaged FUNCTION menu mapping is missing\n' >&2
    exit 1
}
install -m 0644 "$DRASTIC_BUILD/integration-LICENSE" \
    "$PLUMOS_DIR/licenses/steward-fu-nds-LGPL-2.1"
install -m 0644 "$DRASTIC_BUILD/upstream-release-readme.txt" \
    "$PLUMOS_DIR/licenses/drastic-upstream-release-readme.txt"
rsync -a "$PPSSPP_BUILD/runtime/" \
    "$PLUMOS_DIR/emulator/standalone/ppsspp/"
install -m 0644 "$PPSSPP_BUILD/LICENSE.txt" \
    "$PLUMOS_DIR/licenses/ppsspp-LICENSE.txt"
rsync -a \
    --exclude='checksums.sha256' \
    --exclude='LICENSE' \
    --exclude='SDL2-gfx-copyright' \
    "$OPENBOR_BUILD/" \
    "$PLUMOS_DIR/emulator/standalone/openbor/"
# OpenBOR's generic Debian SDL2 can open KMSDRM, but its software renderer
# cannot create the requested output surface on Bubble. Reuse the same minimal
# KMSDRM/ALSA/GLES2 SDL2 build that is already validated by Pyxel and PCSX.
install -m 0644 "$PCSX_SDL2_BUILD/stage/usr/lib/libSDL2-2.0.so.0" \
    "$PLUMOS_DIR/emulator/standalone/openbor/lib/libSDL2-2.0.so.0"
install -m 0644 "$OPENBOR_BUILD/LICENSE" \
    "$PLUMOS_DIR/licenses/openbor-LICENSE"
install -m 0644 "$OPENBOR_BUILD/SDL2-gfx-copyright" \
    "$PLUMOS_DIR/licenses/openbor-SDL2-gfx-copyright"

cat >"$PLUMOS_DIR/components/standalone/manifest.json" <<EOF
{
  "name": "plumOS Bubble standalone emulators",
  "device": "bubble",
  "source_ref": "pcsx-rearmed:$PCSX_REF sdl12-compat:$SDL12_REF sdl2:2.32.0 yabasanshiro:$YABASANSHIRO_REF steward-fu-nds:$DRASTIC_REF ppsspp:$PPSSPP_REF openbor:$OPENBOR_REF",
  "patches": {
    "pcsx-rearmed-bubble-kmsdrm": "$PCSX_PATCH_SHA256",
    "pcsx-rearmed-bubble-gles-ordered-batch": "$PCSX_BATCH_PATCH_SHA256",
    "libpicofe-bubble-kmsdrm": "$PICOFE_PATCH_SHA256",
    "yabasanshiro-bubble-standalone": "$YABASANSHIRO_STANDALONE_PATCH_SHA256",
    "yabasanshiro-bubble-vdp1-framebuffer-readback": "$YABASANSHIRO_FRAMEBUFFER_PATCH_SHA256",
    "yabasanshiro-bubble-vdp1-readback": "$YABASANSHIRO_READBACK_PATCH_SHA256",
    "yabasanshiro-bubble-input": "$YABASANSHIRO_INPUT_PATCH_SHA256",
    "yabasanshiro-bubble-sched-other": "$YABASANSHIRO_SCHED_OTHER_PATCH_SHA256",
    "steward-fu-nds-bubble-toolchain": "$DRASTIC_BUILD_PATCH_SHA256",
    "drastic-bubble-mmap-compat": "$DRASTIC_MMAP_COMPAT_SHA256",
    "ppsspp-bubble-no-sdl2-ttf": "$PPSSPP_PATCH_SHA256",
    "openbor-v6391-bubble": "$OPENBOR_PATCH_SHA256"
  },
  "render_contract": "builtin-neon-default-with-vendor-mali-g52-presentation",
  "external_runtime": ["/dev/dri/card0", "/dev/mali0"],
  "captured_vendor_gpu": {
    "source": "Bubble stockOS read-only capture",
    "distribution": "local-device-validation-only",
    "release_eligible": false,
    "aarch64_sha256": "$(sha256sum "$VENDOR_MALI_AARCH64" | awk '{print $1}')",
    "armhf_sha256": "$(sha256sum "$VENDOR_MALI_ARMHF" | awk '{print $1}')"
  },
  "emulators": [
    {
      "id": "pcsx_rearmed",
      "binary": "emulator/standalone/pcsx_rearmed/pcsx",
      "renderer": "builtin_gpu",
      "optional_renderer": "emulator/standalone/pcsx_rearmed/plugins/gpu_gles.so"
    },
    {
      "id": "yabasanshiro",
      "binary": "emulator/standalone/yabasanshiro/yabasanshiro",
      "renderer": "mali-g52-gles",
      "menu_readback": "full-vdp1-framebuffer-coherent-dma",
      "scheduler": "SCHED_OTHER"
    },
    {
      "id": "drastic",
      "binary": "emulator/standalone/drastic/drastic",
      "core_source": "closed-release-blob",
      "integration": "verified-prebuilt-armhf-sdl2-input-video",
      "runtime": "package-local-armhf",
      "renderer": "aarch64-gles-runner-with-armhf-shared-memory-producer",
      "input": "/dev/input/event2",
      "menu": "function1-keycode-704",
      "route_status": "implemented-pending-device-acceptance"
    },
    {
      "id": "ppsspp",
      "binary": "emulator/standalone/ppsspp/bin/PPSSPPSDL",
      "version": "1.20.4",
      "target_cpu": "cortex-a55",
      "renderer": "mali-g52-kmsdrm-gles2",
      "audio": "alsa-plumos-output",
      "input": "retrogame_joypad",
      "thread_affinity": "startup-only-render-cpu3-workers-cpu0-2"
    },
    {
      "id": "openbor",
      "binary": "emulator/standalone/openbor/bin/OpenBOR",
      "version": "v6391",
      "target_cpu": "cortex-a55",
      "renderer": "bubble-sdl2-kmsdrm-gles2",
      "audio": "alsa-plumos-output",
      "input": "retrogame_joypad",
      "menu": "function-button"
    }
  ]
}
EOF

(
    cd "$PLUMOS_DIR"
    find \
        bin/plumos-standalone-launch \
        emulator/lib \
        emulator/standalone \
        factory-defaults/standalone \
        licenses/pcsx-rearmed-standalone-COPYING \
        licenses/sdl12-compat-LICENSE \
        licenses/pcsx-sdl2-LICENSE.txt \
        licenses/yabasanshiro-LICENSE \
        licenses/steward-fu-nds-LGPL-2.1 \
        licenses/drastic-upstream-release-readme.txt \
        licenses/ppsspp-LICENSE.txt \
        licenses/openbor-LICENSE \
        licenses/openbor-SDL2-gfx-copyright \
        components/standalone/manifest.json \
        -type f -print |
        sort |
        while IFS= read -r path; do sha256sum "$path"; done
) >"$PLUMOS_DIR/components/standalone/checksums.sha256"
(
    cd "$PLUMOS_DIR"
    sha256sum -c components/standalone/checksums.sha256
)
printf 'created: %s\n' "$OUT_ROOT"
