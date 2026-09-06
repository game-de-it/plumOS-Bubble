#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
pyxel=$repo_root/scripts/build-pyxel-bubble.sh
pm_gui=$repo_root/package/portmaster-bubble/plumos/bin/plumos-portmaster-launch
pm_port=$repo_root/package/portmaster-bubble/plumos/bin/plumos-portmaster-port-launch
standalone=$repo_root/package/standalone-bubble/plumos/bin/plumos-standalone-launch
matrix=$repo_root/scripts/run-bubble-emulator-device-matrix.py

for script in "$pyxel" "$pm_gui" "$pm_port"; do
    if grep -Eq 'export (LIBGL_ALWAYS_SOFTWARE|MESA_LOADER_DRIVER_OVERRIDE)=' "$script"; then
        printf 'software GL is forced by %s\n' "$script" >&2
        exit 1
    fi
done

grep -Fq 'Bubble Mali hardware runtime is unavailable' "$pyxel"
grep -Fq 'software_fallback": false' "$pyxel"
grep -Fq 'Bubble Mali hardware runtime is unavailable' "$pm_gui"
grep -Fq 'SDL_VIDEO_EGL_DRIVER="${SDL_VIDEO_EGL_DRIVER:-$mali_library}"' "$pm_gui"
grep -Fq 'renderer_policy=port-owned-hardware-preferred software_forced=false' "$pm_port"
grep -Fq 'MALI_LIBRARY="${PLUMOS_ROOT}/emulator/lib/libmali.so.1"' "$pm_port"
grep -Fq 'export SDL_VIDEO_EGL_DRIVER="$MALI_LIBRARY"' "$pm_port"
grep -Fq 'export SDL_VIDEO_GL_DRIVER="$MALI_LIBRARY"' "$pm_port"
grep -Fq 'renderer_runtime=mali-canonical drm_share=%s' "$pm_port"
grep -Fq 'ppsspp_start=renderer-mali-g52-gles loader-canonical-libmali' "$standalone"
grep -Fq 'mali_preload=' "$standalone"
grep -Fq 'drm_share_preload' "$standalone"
grep -Fq 'export SDL_VIDEO_EGL_DRIVER="$PLUMOS_ROOT/emulator/lib/libmali.so.1"' "$standalone"
grep -Fq 'export SDL_VIDEO_GL_DRIVER="$PLUMOS_ROOT/emulator/lib/libmali.so.1"' "$standalone"
grep -Fq 'failed_software_gl_loaded' "$matrix"
grep -Fq 'failed_mali_not_loaded' "$matrix"

printf 'bubble_hardware_rendering_policy=result-ok pyxel=mali-required portmaster_gui=mali-required ppsspp=canonical-mali ports=canonical-mali\n'
