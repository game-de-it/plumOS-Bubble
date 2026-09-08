#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
image=${PLUMOS_BUBBLE_TOOLS_IMAGE:-plumos-bubble-tools:dev}
if [ "${1:-}" != --inside ]; then
    exec docker run --rm --platform linux/arm64 \
        -v "$repo_root:/work" -w /work "$image" \
        ./tests/test-bubble-retroarch-launch.sh --inside
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
root=$tmp/plumos
rom_root=$tmp/roms
runtime=$tmp/run
mkdir -p "$root/bin" "$root/cores" \
    "$root/factory-defaults/retroarch" "$root/factory-defaults/shaders" \
    "$rom_root/nes" "$rom_root/n64" "$rom_root/gamegear" \
    "$rom_root/megadrive" \
    "$rom_root/easyrpg/ValidGame" "$rom_root/easyrpg/InvalidGame" "$runtime"
cp package/frontend-bubble/plumos/bin/plumos-retroarch-launch \
    "$root/bin/plumos-retroarch-launch"
cp package/frontend-bubble/plumos/bin/plumos-retroarch-config-merge \
    "$root/bin/plumos-retroarch-config-merge"
cp configs/retroarch/bubble-software-drm.cfg \
    "$root/factory-defaults/retroarch/retroarch-bubble.cfg"
cp configs/retroarch/shaders/gamegear-lcd.glslp \
    configs/retroarch/shaders/gamegear-lcd-panel-only.glslp \
    configs/retroarch/shaders/gamegear-lcd-response.glsl \
    configs/retroarch/shaders/gamegear-lcd-panel.glsl \
    configs/retroarch/shaders/gamegear-lcd-optics.glsl \
    "$root/factory-defaults/shaders/"
# RetroArch backs the 160x144 first pass with a 256x256 GLES FBO on Bubble.
# TextureSize is correct for texel addressing, but all content position and
# output-scale decisions must use InputSize or host previews cannot match it.
panel_shader=configs/retroarch/shaders/gamegear-lcd-panel.glsl
grep -Fq 'vec2 content_uv = cell / InputSize;' "$panel_shader"
grep -Fq 'float horizontal_tube_distance(vec2 uv)' "$panel_shader"
grep -Fq 'float edge_response = tube_edge_response(content_uv);' "$panel_shader"
grep -Fq '#define gg_dark_smear 0.90' "$panel_shader"
grep -Fq '#define gg_rowgap    0.00' "$panel_shader"
! grep -Fq 'step(0.50, phase.x)' "$panel_shader"
grep -Fq 'float tube_light = 0.936 - 0.522 * away_from_tube;' "$panel_shader"
grep -Fq '"dark_smear": 0.90' scripts/preview-gamegear-lcd.py
grep -Fq '"rowgap": 0.00' scripts/preview-gamegear-lcd.py
grep -Fq 'periodic_box_coverage(u * sw, sw / ow, 0.75, 1.00)' scripts/preview-gamegear-lcd.py
grep -Fq 'rgbk_mean = (0.25 * (2.0 + b_band_transmission) +' scripts/preview-gamegear-lcd.py
grep -Fq 'periodic_box_coverage(cell.x, quad_width, 0.75, 1.00)' "$panel_shader"
grep -Fq '0.25 * (2.0 + B_BAND_TRANSMISSION)' "$panel_shader"
grep -Fq 'const float B1_OUTPUT_MATCH = 1.523;' "$panel_shader"
grep -Fq 'b1_output_match = 1.523' scripts/preview-gamegear-lcd.py
grep -Fq 'const float B_BAND_TRANSMISSION = 0.25;' "$panel_shader"
grep -Fq 'b_band_transmission = 0.25' scripts/preview-gamegear-lcd.py
grep -Fq 'const float RG_BAND_TRANSMISSION = 0.85;' "$panel_shader"
grep -Fq 'rg_band_transmission = 0.85' scripts/preview-gamegear-lcd.py
grep -Fq '#define gg_black     0.12' "$panel_shader"
grep -Fq '"black": 0.12' scripts/preview-gamegear-lcd.py
grep -Fq '#define gg_bluesat   1.20' "$panel_shader"
grep -Fq '"bluesat": 1.20' scripts/preview-gamegear-lcd.py
grep -Fq '#define gg_blueweak  0.15' "$panel_shader"
grep -Fq '"blueweak": 0.15' scripts/preview-gamegear-lcd.py
grep -Fq '#define gg_aperture  1.00' "$panel_shader"
grep -Fq '"aperture": 1.00' scripts/preview-gamegear-lcd.py
grep -Fq 'const float B1_REFERENCE_MEAN = 0.912;' "$panel_shader"
grep -Fq 'tube_light = 0.936 - 0.522 * edge_response' scripts/preview-gamegear-lcd.py
grep -Fq 'float scale_x = OutputSize.x / InputSize.x;' "$panel_shader"
grep -Fq 'float vertical_scale = OutputSize.y / InputSize.y;' "$panel_shader"
grep -Fq 'backlight(content_uv)' "$panel_shader"
grep -Fq 'vTex - vec2(0.0, texel.y)).rgb;' "$panel_shader"
! grep -Fq 'float panel_radius = length(' "$panel_shader"
: >"$root/cores/quicknes_libretro.so"
: >"$root/cores/parallel_n64_libretro.so"
: >"$root/cores/easyrpg_libretro.so"
: >"$root/cores/genesis_plus_gx_libretro.so"
: >"$rom_root/nes/test.nes"
: >"$rom_root/n64/test.z64"
: >"$rom_root/gamegear/test.gg"
: >"$rom_root/megadrive/test.md"
: >"$rom_root/easyrpg/ValidGame/RPG_RT.ldb"

cat >"$root/bin/retroarch" <<'EOF'
#!/bin/sh
set -eu
: "${TEST_TRACE:?}"
printf '%s\n' "$@" >"$TEST_TRACE.args"
append=
while [ "$#" -gt 0 ]; do
    if [ "$1" = --appendconfig ]; then append=$2; shift 2; else shift; fi
done
if [ -n "$append" ]; then cp "$append" "$TEST_TRACE.append"; fi
printf '%s\n' "$$" >"$TEST_TRACE.pid"
if [ "${TEST_HOLD:-0}" = 1 ]; then
    trap 'exit 0' TERM
    while :; do sleep 1; done
fi
EOF
cat >"$root/bin/plumos-audio-output" <<'EOF'
#!/bin/sh
mkdir -p "${PLUMOS_RUNTIME_ROOT:-/run/plumos}/audio"
: >"${PLUMOS_RUNTIME_ROOT:-/run/plumos}/audio/asound.conf"
EOF
cat >"$root/bin/plumos-volume-control" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$root/bin/plumos-cpu-control" <<'EOF'
#!/bin/sh
case "$1" in
    snapshot) printf '%s\n' 'policy0=ondemand' >"$2" ;;
    apply|restore) ;;
    *) exit 2 ;;
esac
EOF
chmod 0755 "$root/bin/retroarch" "$root/bin/plumos-retroarch-launch" \
    "$root/bin/plumos-retroarch-config-merge" "$root/bin/plumos-audio-output" \
    "$root/bin/plumos-volume-control" "$root/bin/plumos-cpu-control"

run_launcher() {
    trace=$1
    shift
    TEST_TRACE=$trace PLUMOS_ROOT=$root PLUMOS_ROM_ROOT=$rom_root \
    PLUMOS_RUNTIME_ROOT=$runtime PLUMOS_BUSYBOX=/bin/busybox \
        "$root/bin/plumos-retroarch-launch" "$@"
}

run_launcher "$tmp/software" --system nes \
    --core "$root/cores/quicknes_libretro.so" \
    --rom "$rom_root/nes/test.nes"
grep -qx -- --appendconfig "$tmp/software.args"
grep -qx 'video_driver = "drm"' "$tmp/software.append"
grep -qx 'video_context_driver = ""' "$tmp/software.append"
grep -qx 'video_threaded = "true"' "$tmp/software.append"
grep -qx 'system_directory = "/storage/BIOS"' "$tmp/software.append"
grep -qx 'log_to_file = "false"' "$tmp/software.append"
grep -qx 'savefiles_in_content_dir = "false"' "$tmp/software.append"
grep -qx 'savestates_in_content_dir = "false"' "$tmp/software.append"
grep -qx "savefile_directory = \"$root/saves\"" "$tmp/software.append"
grep -qx "savestate_directory = \"$root/states\"" "$tmp/software.append"
grep -qx 'audio_device = "plumos_output"' "$tmp/software.append"
! grep -q '^config_save_on_exit = ' "$tmp/software.append"
! grep -qx -- --set-shader "$tmp/software.args"
! find "$runtime/retroarch" -type f -name 'launch.*.cfg' -print -quit | grep -q .

# Game Gear owns a system-specific GLSL preset. It must select KMS/EGL/GLES
# even with the software core and RGUI, without turning shaders on globally or
# creating a Genesis Plus GX core preset that would leak into other systems.
mkdir -p "$root/config/shaders"
printf '%s\n' 'user-edited-panel' >"$root/config/shaders/gamegear-lcd-panel.glsl"
run_launcher "$tmp/gamegear-full" --system gamegear \
    --core "$root/cores/genesis_plus_gx_libretro.so" \
    --rom "$rom_root/gamegear/test.gg"
grep -qx 'video_driver = "gl"' "$tmp/gamegear-full.append"
grep -qx 'video_context_driver = "kms"' "$tmp/gamegear-full.append"
grep -qx 'video_shader_enable = "true"' "$tmp/gamegear-full.append"
# The SEGA panel route is 4:3; coverage integration keeps its non-square dots
# stable at 4.00x/3.33x.
grep -qx 'aspect_ratio_index = "23"' "$tmp/gamegear-full.append"
grep -qx 'custom_viewport_width = "640"' "$tmp/gamegear-full.append"
grep -qx 'custom_viewport_height = "480"' "$tmp/gamegear-full.append"
grep -qx 'custom_viewport_x = "0"' "$tmp/gamegear-full.append"
grep -qx 'custom_viewport_y = "0"' "$tmp/gamegear-full.append"
grep -qx -- --set-shader "$tmp/gamegear-full.args"
grep -qx "$root/config/shaders/gamegear-lcd.glslp" \
    "$tmp/gamegear-full.args"
grep -qx 'user-edited-panel' "$root/config/shaders/gamegear-lcd-panel.glsl"
test -f "$root/config/shaders/gamegear-lcd-response.glsl"
test -f "$root/config/shaders/gamegear-lcd-optics.glsl"
test -f "$root/config/shaders/gamegear-lcd-panel-only.glslp"

TEST_TRACE=$tmp/gamegear-panel \
PLUMOS_GAMEGEAR_LCD_PRESET=panel-only \
PLUMOS_ROOT=$root PLUMOS_ROM_ROOT=$rom_root \
PLUMOS_RUNTIME_ROOT=$runtime PLUMOS_BUSYBOX=/bin/busybox \
    "$root/bin/plumos-retroarch-launch" --system gamegear \
    --core "$root/cores/genesis_plus_gx_libretro.so" \
    --rom "$rom_root/gamegear/test.gg"
grep -qx "$root/config/shaders/gamegear-lcd-panel-only.glslp" \
    "$tmp/gamegear-panel.args"
grep -qx 'custom_viewport_width = "640"' "$tmp/gamegear-panel.append"
grep -qx 'custom_viewport_height = "480"' "$tmp/gamegear-panel.append"

TEST_TRACE=$tmp/gamegear-integer3x \
PLUMOS_GAMEGEAR_LCD_GEOMETRY=integer3x \
PLUMOS_ROOT=$root PLUMOS_ROM_ROOT=$rom_root \
PLUMOS_RUNTIME_ROOT=$runtime PLUMOS_BUSYBOX=/bin/busybox \
    "$root/bin/plumos-retroarch-launch" --system gamegear \
    --core "$root/cores/genesis_plus_gx_libretro.so" \
    --rom "$rom_root/gamegear/test.gg"
grep -qx 'custom_viewport_width = "480"' "$tmp/gamegear-integer3x.append"
grep -qx 'custom_viewport_height = "432"' "$tmp/gamegear-integer3x.append"

TEST_TRACE=$tmp/gamegear-off \
PLUMOS_GAMEGEAR_LCD_PRESET=off \
PLUMOS_ROOT=$root PLUMOS_ROM_ROOT=$rom_root \
PLUMOS_RUNTIME_ROOT=$runtime PLUMOS_BUSYBOX=/bin/busybox \
    "$root/bin/plumos-retroarch-launch" --system gamegear \
    --core "$root/cores/genesis_plus_gx_libretro.so" \
    --rom "$rom_root/gamegear/test.gg"
grep -qx 'video_driver = "drm"' "$tmp/gamegear-off.append"
! grep -q '^video_shader_enable = ' "$tmp/gamegear-off.append"
# Without the shader there is nothing to align, so the picture is left to fill
# the screen as it does for every other system.
! grep -q '^custom_viewport_width = ' "$tmp/gamegear-off.append"
! grep -q '^aspect_ratio_index = ' "$tmp/gamegear-off.append"
! grep -qx -- --set-shader "$tmp/gamegear-off.args"

set +e
TEST_TRACE=$tmp/gamegear-invalid \
PLUMOS_GAMEGEAR_LCD_PRESET=unknown \
PLUMOS_ROOT=$root PLUMOS_ROM_ROOT=$rom_root \
PLUMOS_RUNTIME_ROOT=$runtime PLUMOS_BUSYBOX=/bin/busybox \
    "$root/bin/plumos-retroarch-launch" --system gamegear \
    --core "$root/cores/genesis_plus_gx_libretro.so" \
    --rom "$rom_root/gamegear/test.gg" \
    >"$tmp/gamegear-invalid.log" 2>&1
gamegear_invalid_rc=$?
set -e
test "$gamegear_invalid_rc" -eq 2
grep -q 'invalid Game Gear LCD preset' "$tmp/gamegear-invalid.log"
test ! -e "$tmp/gamegear-invalid.args"

set +e
TEST_TRACE=$tmp/gamegear-invalid-geometry \
PLUMOS_GAMEGEAR_LCD_GEOMETRY=unknown \
PLUMOS_ROOT=$root PLUMOS_ROM_ROOT=$rom_root \
PLUMOS_RUNTIME_ROOT=$runtime PLUMOS_BUSYBOX=/bin/busybox \
    "$root/bin/plumos-retroarch-launch" --system gamegear \
    --core "$root/cores/genesis_plus_gx_libretro.so" \
    --rom "$rom_root/gamegear/test.gg" \
    >"$tmp/gamegear-invalid-geometry.log" 2>&1
gamegear_invalid_geometry_rc=$?
set -e
test "$gamegear_invalid_geometry_rc" -eq 2
grep -q 'invalid Game Gear LCD geometry' "$tmp/gamegear-invalid-geometry.log"
test ! -e "$tmp/gamegear-invalid-geometry.args"

run_launcher "$tmp/megadrive-same-core" --system megadrive \
    --core "$root/cores/genesis_plus_gx_libretro.so" \
    --rom "$rom_root/megadrive/test.md"
grep -qx 'video_driver = "drm"' "$tmp/megadrive-same-core.append"
! grep -q '^video_shader_enable = ' "$tmp/megadrive-same-core.append"
! grep -qx -- --set-shader "$tmp/megadrive-same-core.args"

# Bubble exposes SD2 through /storage/Roms -> /storage/user/Roms while the
# scanner records the resolved /storage/user/Roms path.  Both names identify
# the same managed ROM tree and must pass the traversal guard.
ln -s "$rom_root" "$tmp/rom-link"
TEST_TRACE=$tmp/symlink PLUMOS_ROOT=$root PLUMOS_ROM_ROOT=$tmp/rom-link \
PLUMOS_RUNTIME_ROOT=$runtime PLUMOS_BUSYBOX=/bin/busybox \
    "$root/bin/plumos-retroarch-launch" --system nes \
    --core "$root/cores/quicknes_libretro.so" \
    --rom "$rom_root/nes/test.nes"
grep -qx "$rom_root/nes/test.nes" "$tmp/symlink.args"

# The FE presents each EasyRPG project directory as one game.  Resolve that
# directory to the core-compatible RPG_RT.ldb marker used by the device matrix.
run_launcher "$tmp/easyrpg" --system easyrpg \
    --core "$root/cores/easyrpg_libretro.so" \
    --rom "$rom_root/easyrpg/ValidGame"
grep -qx "$rom_root/easyrpg/ValidGame/RPG_RT.ldb" "$tmp/easyrpg.args"

set +e
run_launcher "$tmp/easyrpg-invalid" --system easyrpg \
    --core "$root/cores/easyrpg_libretro.so" \
    --rom "$rom_root/easyrpg/InvalidGame" \
    >"$tmp/easyrpg-invalid.log" 2>&1
easyrpg_invalid_rc=$?
set -e
test "$easyrpg_invalid_rc" -eq 1
grep -q 'EasyRPG project directory is missing RPG_RT.ldb' \
    "$tmp/easyrpg-invalid.log"
test ! -e "$tmp/easyrpg-invalid.args"

set +e
TEST_TRACE=$tmp/escape PLUMOS_ROOT=$root PLUMOS_ROM_ROOT=$tmp/rom-link \
PLUMOS_RUNTIME_ROOT=$runtime PLUMOS_BUSYBOX=/bin/busybox \
    "$root/bin/plumos-retroarch-launch" --system nes \
    --core "$root/cores/quicknes_libretro.so" \
    --rom "$root/cores/quicknes_libretro.so" \
    >"$tmp/escape.log" 2>&1
escape_rc=$?
set -e
test "$escape_rc" -eq 2
grep -q 'ROM path escaped configured ROM root' "$tmp/escape.log"

sed -i 's/^menu_driver = "rgui"$/menu_driver = "xmb"/' \
    "$root/config/retroarch/retroarch-bubble.cfg"
run_launcher "$tmp/xmb" --system nes \
    --core "$root/cores/quicknes_libretro.so" \
    --rom "$rom_root/nes/test.nes"
grep -qx 'video_driver = "gl"' "$tmp/xmb.append"
grep -qx 'video_context_driver = "kms"' "$tmp/xmb.append"
sed -i 's/^menu_driver = "xmb"$/menu_driver = "rgui"/' \
    "$root/config/retroarch/retroarch-bubble.cfg"

run_launcher "$tmp/hardware" --system n64 \
    --core "$root/cores/parallel_n64_libretro.so" \
    --rom "$rom_root/n64/test.z64"
grep -qx 'video_driver = "gl"' "$tmp/hardware.append"
grep -qx 'video_context_driver = "kms"' "$tmp/hardware.append"
grep -qx 'video_threaded = "true"' "$tmp/hardware.append"
grep -qx 'system_directory = "/storage/BIOS"' "$tmp/hardware.append"
grep -qx 'log_to_file = "false"' "$tmp/hardware.append"
grep -qx 'savefiles_in_content_dir = "false"' "$tmp/hardware.append"
grep -qx 'savestates_in_content_dir = "false"' "$tmp/hardware.append"
grep -qx 'audio_device = "plumos_output"' "$tmp/hardware.append"
! grep -q '^config_save_on_exit = ' "$tmp/hardware.append"
! find "$runtime/retroarch" -type f -name 'launch.*.cfg' -print -quit | grep -q .

TEST_TRACE=$tmp/signal TEST_HOLD=1 PLUMOS_ROOT=$root \
PLUMOS_ROM_ROOT=$rom_root PLUMOS_RUNTIME_ROOT=$runtime \
PLUMOS_BUSYBOX=/bin/busybox \
    "$root/bin/plumos-retroarch-launch" --system nes \
    --core "$root/cores/quicknes_libretro.so" \
    --rom "$rom_root/nes/test.nes" &
launcher_pid=$!
i=0
while [ ! -s "$tmp/signal.pid" ] && [ "$i" -lt 50 ]; do
    /bin/busybox usleep 100000
    i=$((i + 1))
done
test -s "$tmp/signal.pid"
child_pid=$(cat "$tmp/signal.pid")
kill -TERM "$launcher_pid"
set +e
wait "$launcher_pid"
launcher_rc=$?
set -e
test "$launcher_rc" -eq 143
! kill -0 "$child_pid" 2>/dev/null

echo 'bubble_retroarch_launcher_test=result-ok'
