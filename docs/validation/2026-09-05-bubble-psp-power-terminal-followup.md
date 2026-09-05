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

## PPSSPP correction

Bubble and MF use the same PPSSPP 1.20.4 revision, factory configuration,
GLES2 backend and Cortex-A55 build flags. The Bubble log repeatedly showed
Thin3D program link failures for both the synthetic PSP probe and Star Soldier.
The affected Thin3D vertex shaders use the GLES vertex default precision while
their fragment partners explicitly selected `lowp`. Bubble's captured Mali
driver rejects the mismatched varying interface.

Patch `ppsspp-1.20.4-bubble-mali-thin3d-precision.patch` changes the three
Thin3D fragment shaders to `mediump`, matching PPSSPP's existing fragment
prelude and retaining the Mali KMSDRM/GLES2 hardware renderer. It does not
enable software rendering. The source-built binary has SHA-256
`7e60cd2bb02bdf3f325577b653ef23b07fedc20545ed0a6c0aa50ae0935b8199`.
The standalone component verified at 860/860 after deployment.

Physical acceptance still requires a normal boot followed by launching Star
Soldier through the frontend and checking picture, sound, controls, normal
return, Reboot and Shutdown.

## Metadata note

The device's existing global `checksums.sha256` has 12,890 entries and predates
this deployment with 5,225 invalid checks caused by malformed separators and
references to removed incoming/rollback files. Regenerating that list from the
live device would incorrectly bless mutable PortMaster and user-owned state, so
this deployment did not do that. It updated and verified only the eight global
entries changed here, in addition to both complete component lists. Repairing
the legacy global inventory requires a separate source-of-truth reconciliation.
