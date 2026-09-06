#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

contract=configs/input/bubble-controller-map.json
test "$(jq -r '.device.name' "$contract")" = retrogame_joypad
test "$(jq -r '.device.axis_count' "$contract")" -eq 4
test "$(jq -r '.device.button_count' "$contract")" -eq 18

expected_buttons='304 305 307 308 310 311 312 313 314 315 316 317 318 544 545 546 547 704'
actual_buttons=$(jq -r '.buttons | sort_by(.js_button) | map(.evdev_code) | join(" ")' "$contract")
test "$actual_buttons" = "$expected_buttons"
test "$(jq -r '.buttons[] | select(.physical == "A") | [.evdev_name, .js_button, .retropad] | join(" ")' "$contract")" = 'BTN_EAST 1 A'
test "$(jq -r '.buttons[] | select(.physical == "B") | [.evdev_name, .js_button, .retropad] | join(" ")' "$contract")" = 'BTN_SOUTH 0 B'
test "$(jq -r '.buttons[] | select(.physical == "Function1") | [.evdev_code, .js_button] | join(" ")' "$contract")" = '704 17'
test "$(jq -r '.buttons[] | select(.physical == "Function2") | [.evdev_code, .js_button] | join(" ")' "$contract")" = '316 10'
test "$(jq -r '.axes | sort_by(.js_axis) | map(.evdev_code) | join(" ")' "$contract")" = '0 1 3 4'

grep -Fq 'case BTN_TRIGGER_HAPPY1:' src/frontend/plumos_controller_ui.c
grep -Fq 'input_b_btn = "0"' configs/retroarch/autoconfig/udev/gkd-bubble-retrogame-joypad.cfg
grep -Fq 'input_a_btn = "1"' configs/retroarch/autoconfig/udev/gkd-bubble-retrogame-joypad.cfg
grep -Fq 'input_menu_toggle_btn = "17"' configs/retroarch/autoconfig/udev/gkd-bubble-retrogame-joypad.cfg
grep -Fq 'input_screenshot_btn = "10"' configs/retroarch/autoconfig/udev/gkd-bubble-retrogame-joypad.cfg

pico_patch=package/picoarch-bubble/patches/picoarch-bubble-physical-input.patch
grep -Fq '{ BTN_EAST,   IN_BINDTYPE_PLAYER12, RETRO_DEVICE_ID_JOYPAD_A }' "$pico_patch"
grep -Fq '{ BTN_SOUTH,  IN_BINDTYPE_PLAYER12, RETRO_DEVICE_ID_JOYPAD_B }' "$pico_patch"
grep -Fq 'case BTN_EAST: /* physical A on Bubble */' src/frontend/plumos_ggfe.c
grep -Fq 'case BTN_NORTH: /* physical X on Bubble */' src/frontend/plumos_ggfe.c
grep -Fq 'case BTN_SOUTH: /* physical B on Bubble */' src/frontend/plumos_ggfe.c
grep -Fq 'ggfe_input=case-toggle code=%u visible=%d' src/frontend/plumos_ggfe.c
grep -Fq 'ggfe_browse_frame(pos, show_cases, &frame);' src/frontend/plumos_ggfe.c
grep -Fq 'ggfe_input=reopened-after-launch' src/frontend/plumos_ggfe.c
awk '
  /if \(launch_t > GGFE_LAUNCH_END\)/ { in_handoff=1 }
  in_handoff && /close\(input_fd\)/ { saw_close=1 }
  in_handoff && /ggfe_launch_rom\(/ { saw_launch=1 }
  in_handoff && /input_fd = ggfe_open_input\(\)/ { saw_reopen=1; exit }
  END { exit !(saw_close && saw_launch && saw_reopen) }
' src/frontend/plumos_ggfe.c
grep -Fq '#define GGFE_TARGET_FPS 60.0f' src/frontend/plumos_ggfe.c
# The scroll duration is no longer a constant: both carousel motions are
# selectable from ggfe.json, and the shipped default is GGFE's own snap.
grep -Fq 'GGFE_MOTION_SNAP' src/frontend/plumos_ggfe.c
grep -Fq 'GGFE_MOTION_GALLERY' src/frontend/plumos_ggfe.c
grep -Fq '#define GGFE_KEY_REPEAT_DELAY_MS 350' src/frontend/plumos_ggfe.c
grep -Fq '#define GGFE_KEY_REPEAT_INTERVAL_MS 95' src/frontend/plumos_ggfe.c
grep -Fq '#define GGFE_PAGE_JUMP 5' src/frontend/plumos_ggfe.c
grep -Fq 'ggfe_repeat_press(&repeat, (unsigned int)ev.code, -1' src/frontend/plumos_ggfe.c
grep -Fq 'ggfe_repeat_press(&repeat, (unsigned int)ev.code, 1' src/frontend/plumos_ggfe.c
grep -Fq 'ggfe_scroll_request(&app, &scroll, -GGFE_PAGE_JUMP);' src/frontend/plumos_ggfe.c
grep -Fq 'ggfe_scroll_request(&app, &scroll, GGFE_PAGE_JUMP);' src/frontend/plumos_ggfe.c
python3 - package/frontend-bubble/plumos/config/frontend/ggfe.json <<'PY'
import json, sys
motion = json.load(open(sys.argv[1])).get("motion", {})
assert motion.get("model") == "snap", motion
assert 60 <= int(motion.get("scroll_ms", 0)) <= 2000, motion
PY
grep -Fq 'ggfe_warm_labels(app, next);' src/frontend/plumos_ggfe.c
grep -Fq '{ BTN_THUMBL, IN_BINDTYPE_PLAYER12, RETRO_DEVICE_ID_JOYPAD_L3 }' "$pico_patch"
grep -Fq '{ BTN_THUMBR, IN_BINDTYPE_PLAYER12, RETRO_DEVICE_ID_JOYPAD_R3 }' "$pico_patch"
grep -Fq '{ BTN_TRIGGER_HAPPY1, IN_BINDTYPE_EMU, EACTION_MENU }' "$pico_patch"
! grep -Fq '{ BTN_MODE,   IN_BINDTYPE_EMU, EACTION_MENU }' "$pico_patch"
! grep -Fq '{ BTN_MODE,   PBTN_MENU }' "$pico_patch"
grep -Fq 'SDLK_WORLD_17, IN_BINDTYPE_EMU, SACTION_ENTER_MENU' \
    package/standalone-bubble/patches/pcsx-rearmed-bubble-kmsdrm.patch
! grep -Fq 'SDLK_WORLD_10, IN_BINDTYPE_EMU, SACTION_ENTER_MENU' \
    package/standalone-bubble/patches/pcsx-rearmed-bubble-kmsdrm.patch
grep -Fq 'mapInput("select", Input(joyId, TYPE_BUTTON, 17' \
    package/standalone-bubble/patches/yabasanshiro/yabasanshiro-2.10.4-bubble-input.patch
grep -Fq '"select": {"type": "button", "id": 17' \
    package/standalone-bubble/plumos/factory-defaults/standalone/yabasanshiro/keymapv2.json
grep -Fq 'controls_b[CONTROL_INDEX_MENU] = 1041' scripts/build-drastic-bubble.sh
drastic_patch=package/standalone-bubble/patches/drastic/steward-fu-nds-bubble-toolchain.patch
grep -Fq '#define DEV_KEY_CODE_MENU       316' "$drastic_patch"
grep -Fq '#define DEV_KEY_CODE_DRASTIC    704' "$drastic_patch"
grep -Fq 'if (c == DEV_KEY_CODE_DRASTIC)' "$drastic_patch"
! grep -Fq 'guide:b10' package/standalone-bubble/plumos/bin/plumos-standalone-launch
grep -Fq 'guide:b17' package/standalone-bubble/plumos/bin/plumos-standalone-launch
drm_patch=patches/retroarch/015-bubble-drm-rgui-blocking-commit.patch
grep -Fq 'uint32_t commit_flags = menu_surface ? 0' "$drm_patch"
grep -Fq 'commit_flags, menu_surface ? NULL : &pending' "$drm_patch"
grep -Fq 'scanout_fb=%u waited_ms=%u' "$drm_patch"
resume_patch=patches/retroarch/016-bubble-drm-plane-switch-barrier.patch
grep -Fq 'bool synchronous_commit = menu_surface || plane_switch' "$resume_patch"
grep -Fq 'surface->plane_switch_pending = true' "$resume_patch"
grep -Fq 'Completed synchronous plane-switch barrier' "$resume_patch"
grep -Fq 'fflush(stderr)' "$resume_patch"
mf_pacing_patch=patches/retroarch/017-bubble-drm-mf-blocking-game-commit.patch
grep -Fq 'DRM_MODE_PAGE_FLIP_EVENT;' "$mf_pacing_patch"
grep -Fq -- '-         (DRM_MODE_ATOMIC_NONBLOCK | DRM_MODE_PAGE_FLIP_EVENT);' \
    "$mf_pacing_patch"
grep -Fq 'same blocking atomic commit plus' "$mf_pacing_patch"
! grep -Fq 'ABS_Z/RZ triggers' scripts/build-picoarch-bubble.sh

echo 'bubble_physical_input_contract=result-ok'
