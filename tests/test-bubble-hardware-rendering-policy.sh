#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
pyxel=$repo_root/scripts/build-pyxel-bubble.sh
pm_gui=$repo_root/package/portmaster-bubble/plumos/bin/plumos-portmaster-launch
pm_port=$repo_root/package/portmaster-bubble/plumos/bin/plumos-portmaster-port-launch
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
grep -Fq 'failed_software_gl_loaded' "$matrix"
grep -Fq 'failed_mali_not_loaded' "$matrix"

printf 'bubble_hardware_rendering_policy=result-ok pyxel=mali-required portmaster_gui=mali-required ports=hardware-preferred\n'
