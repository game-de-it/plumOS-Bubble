# Bubble fresh-image emulator regression (2026-09-07)

## Scope

The clean image built from source reference `0dc027a` was booted on the GKD
Bubble with the user's SD2 mounted read-write at `/run/media/sd2`. The supplied
Mac ROM set at `/Volumes/public/02/motoki/emu/ROM/rom2` and the corresponding
files already present on SD2 were not modified. Five representative files
(NES, Game Gear, Mega Drive, vertical arcade and EasyRPG) matched the Mac source
by SHA-256 before execution.

The boot-time library index was empty because storage health retained `dirty`
for the previously uncleanly removed SD2 and the frontend correctly preserved
the existing index instead of performing an automatic scan. An explicit,
read-only scan completed in 249 ms and indexed 915 ROM records. It also exposed
one catalog follow-up: recursive Mega Drive scanning includes
`megadrive/EDMD/SAVE/*.BIN`, so the first automatically selected item was a save
file rather than a ROM. The device matrix used a known ROM2 Mega Drive image
instead.

All bounded emulator probes held runtime volume at zero, isolated mutable
RetroArch/PicoArch/standalone/Pyxel config, saves and states, and stopped the
frontend before another process acquired DRM. Speaker audibility and physical
controls were therefore not inferred from process state.

## Emulator startup matrix

The first pass exercised 29 launch-profile occurrences across NES, Mega Drive,
Game Gear, PSP, NDS, Dreamcast, Saturn, FBNeo, MAME 2003+, EasyRPG, PICO-8 and
Pyxel. Twenty-four started immediately. Two Game Gear rows were missing only
because SSH authentication was transiently refused. The two RetroArch Saturn
rows and MAME 2003+ were initially given the nonexistent case-sensitive path
`/run/media/sd2/BIOS` by the old harness.

The harness now accepts a clean image whose mutable RetroArch config has not yet
been seeded and waits for the PID 1 frontend supervisor before starting its own
recovery fallback. The Game Gear rows were repeated, and ROM2
`saturn_bios.bin` and `sega_101.bin` were SHA-verified into an isolated temporary
BIOS directory. The focused retest result was 10/10 started. Combining later
rows by system/profile gives 29/29 startup results:

- NES: RetroArch and PicoArch QuickNES, FCEUmm and Nestopia, 6/6;
- Mega Drive: Genesis Plus GX and PicoDrive through both frontends, 4/4;
- Game Gear: Genesis Plus GX, PicoDrive and Gearsystem through both frontends,
  6/6;
- PPSSPP with `Star Soldier (Japan).chd`, DraStic with New Super Mario Bros.,
  two Flycast routes, three Saturn routes, FBNeo, MAME 2003+, EasyRPG, two
  PICO-8 routes and Pyxel, 13/13.

Every started row acquired DRM. All 29 advanced the ALSA hardware pointer.
PPSSPP, DraStic, Flycast, YabaSanshiro and Pyxel loaded the Bubble Mali runtime;
no row mapped llvmpipe, softpipe, `swrast_dri` or `kms_swrast`. A second Pyxel
probe used the previously problematic `pfs.pyxapp`; it created a Mali GLES2
KMSDRM context, fitted 256x192 to 640x480, advanced PCM and restored `ondemand`.

The PicoArch Game Gear logs explicitly selected RGB565 byte swapping for both
Gearsystem and PicoDrive. The host matrix also passed all 20 PicoArch core IDs:
18 RGB565, seven corrected byte-order routes, two XRGB8888 routes and one
compatibility alias.

Raw reports are:

- `artifacts/device-validation/2026-09-06-bubble-fresh-image-emulator-regression.json`
- `artifacts/device-validation/2026-09-07-bubble-emulator-focused-retest.json`
- `artifacts/device-validation/2026-09-07-bubble-pyxel-pfs-retest.json`
- `artifacts/device-validation/2026-09-07-bubble-vertical-arcade-isolated-retest.json`

## Display regression found

Horizontal RetroArch contracts and the Pyxel fit contract were centered and
bounded. Vertical arcade is not accepted on this fresh image.

FBNeo Image Fight reported core geometry `384x256`, aspect `0.750` and a
quarter-turn. MAME 2003+ Varth reported `224x384`, aspect `0.750` and the same
vertical request. Both active DRM contracts nevertheless allocated a full
`640x480` viewport with aspect `1.333333` and rotation 3. The intended contract
from the earlier accepted runtime was a centered `360x480` viewport. The
current result rotates the content but stretches its 3:4 presentation to 4:3.

The source-level display contract test still passes, so it does not cover the
fresh factory-config runtime state which reproduces this fault. Physical LCD
observation should be repeated only after the runtime viewport fix; the machine
contract is already sufficient to fail the current image.

## PortMaster and GGFE

Apotris remained alive with the canonical Mali DSO, exclusively owned DRM,
advanced PCM, and returned to one frontend process. Its owned session and all
temporary mounts were removed, while system settings and mutable
`installed.json` hashes stayed unchanged.

The PortMaster GUI exclusively acquired DRM through Mali and remained alive
through 25 seconds without software rendering. The first shorter forced-stop
probe produced an upstream featured-image exception during shutdown; it did not
recur while the GUI was left running. A forced `TERM` of the 25-second launcher
returned before its GUI child had released DRM, allowing the frontend to start
while that child briefly remained a display owner. The validation immediately
stopped the frontend, removed the PortMaster-owned child/mounts, and restored a
single frontend. This forced-termination cleanup race remains open.

GGFE found all 20 Game Gear ROMs, used four worker threads and DRM double
buffering, applied `performance` only while alive, and restored `ondemand`.
With cases enabled at the selected position it measured about 30 fps,
`compose_us` about 19.9--20.6 ms, `blit_us` about 0.85 ms and no emulator was
started. Repeated validation holds exhausted PID 1's four-restart budget, so
the normal frontend did not return after this direct GGFE probe; it was restored
once through `plumos-frontend-launch`. This is a validation-induced lifecycle
limit, not a normal Apps-route acceptance.

## Post-condition

All temporary matrix directories and the two staged BIOS files were removed.
The device ended with one frontend process as the only DRM owner, no PCM owner,
no emulator, PortMaster or GGFE process, no validation hold or temporary bind
mount, runtime volume restored to 8, governor `ondemand`, Wi-Fi at
`192.168.10.101`, and about 5.5 GiB free in `/storage`. Frontend,
libretro-cores, RetroArch, PicoArch, standalone, Pyxel and PortMaster component
checksums all passed after the probes.

Physical speaker output, controls, RetroArch menu open/close and ordinary
in-game exits were not re-accepted in this unattended pass. Those earlier
physical results are not generalized to the new image.
