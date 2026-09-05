# Bubble PSP dark screen and terminal power follow-up

Date: 2026-09-05

## Physical observations

Launching `Star Soldier (Japan).chd` through the PSP frontend route darkened
the display. Selecting Shutdown from the game-owned power overlay returned to
the frontend. A later Reboot selection returned to the power menu instead of
rebooting.

The first attempt before foreground termination support left PPSSPP holding
`/storage/user/Roms`, so the SD2 ROM bind and p4 unmount correctly refused the
unsafe shutdown. After foreground termination support, the next Shutdown
terminated the foreground group, unbound SD2, wrote both clean markers,
unmounted p4 and committed `shutdown` to
`/run/plumos/power-action/request`. It still did not power off because PID 1
checks that request only after its supervised frontend exits. The external
overlay is owned by the volume-key service, so returning from the overlay did
not end the frontend.

## Power correction

`plumos-power-menu-overlay` now terminates the PID published by
`/tmp/plumos-fe-ready` after a terminal request is committed. This returns the
frontend supervisor to PID 1, which consumes the request, remounts p3 read-only
and executes the forced kernel power action. `plumos-safe-shutdown` also:

- keeps network and volume services running until all fallible storage work
  succeeds;
- accepts a repeated committed request while p4 is already cleanly unmounted;
- atomically changes an unconsumed Shutdown request to Reboot, or vice versa,
  without deleting clean-unmount evidence.

Host power-menu, START-menu and managed-volume fixtures passed. The updated
files were deployed with frontend component verification at 164/164. The
previously pending Shutdown was then handed to PID 1 by terminating frontend
PID 1915; the device stopped answering ping immediately, confirming physical
power-off.

## PPSSPP first hypothesis (rejected)

Bubble and MF use the same PPSSPP 1.20.4 revision, factory configuration,
GLES2 backend and Cortex-A55 build flags. The Bubble log repeatedly showed
Thin3D program link failures for both the synthetic PSP probe and Star Soldier.
The affected Thin3D vertex shaders use the GLES vertex default precision while
their fragment partners explicitly selected `lowp`. The first hypothesis was
that Bubble's captured Mali driver rejected this mismatched varying interface.

Patch `ppsspp-1.20.4-bubble-mali-thin3d-precision.patch` changed the three
Thin3D fragment shaders to `mediump`. The source-built binary had SHA-256
`7e60cd2bb02bdf3f325577b653ef23b07fedc20545ed0a6c0aa50ae0935b8199`
and the standalone component verified at 860/860 after deployment. Physical
retest still produced a black display. The new log showed both vertex and
fragment shader compilation failing before program linking, so the varying
precision explanation was wrong. This patch is removed rather than retained
as an unexplained Bubble-only divergence.

## PPSSPP confirmed cause and second correction

PPSSPP directly needs both `libEGL.so.1` and `libGLESv2.so.2`. On the device,
those names and `libmali.so.1` are five separate regular files with different
inodes, although all have the same vendor binary SHA-256. SDL creates the EGL
context through one loaded copy while PPSSPP sends GLES calls through another.
The GLES instance therefore has no current context and rejects every shader,
which is the same loader failure already confirmed and corrected for DraStic.

The PPSSPP launcher now scopes `LD_PRELOAD`, `SDL_VIDEO_EGL_DRIVER` and
`SDL_VIDEO_GL_DRIVER` to the canonical `libmali.so.1`. This preserves the
KMSDRM/GLES2 hardware renderer and does not change the PPSSPP configuration or
enable software rendering.

## PPSSPP physical acceptance after canonical Mali correction

Source `0d8d1ee` was rebuilt without the rejected precision patch and deployed
with the standalone component passing 860/860 checks. The four changed global
checksum entries also passed device readback. The user then launched
`Star Soldier (Japan).chd` through the frontend and reported normal PSP
operation. The latest canonical-Mali session recorded:

- `PPSSPP v1.20.4` and a successful real-content `Booted` event;
- the Mali `g13p0-01eac0` runtime rather than a software renderer;
- zero shader compilation, program-link, G3D, abort or segmentation errors;
- normal `Leaving main`, `ppsspp_exit=rc-0` and frontend resume.

After PPSSPP had returned normally to the frontend, the user selected Reboot.
The power path unbound the SD2 ROM and BIOS views, unmounted SD2, cleanly
unmounted p4, wrote both clean markers and committed the reboot request to PID
1. The next boot has a new boot ID, reached frontend-ready with no foreground
owner, and recorded `previous_shutdown=clean automatic_repair=no`. This proves
the normal post-game Reboot path. Physical terminal-action coverage that kills
a still-running or hung game remains separate and still requires both Reboot
and Shutdown acceptance.

## Metadata note

The device's existing global `checksums.sha256` has 12,890 entries and predates
this deployment with 5,225 invalid checks caused by malformed separators and
references to removed incoming/rollback files. Regenerating that list from the
live device would incorrectly bless mutable PortMaster and user-owned state, so
this deployment did not do that. It updated and verified only the eight global
entries changed here, in addition to both complete component lists. Repairing
the legacy global inventory requires a separate source-of-truth reconciliation.
