# Bubble frontend / RetroArch probe host validation (2026-09-02)

## Scope

This gate advances the already booted external-initramfs three-partition probe
to a common plumOS frontend and a software-only RetroArch/QuickNES baseline.
It does not finalize partition expansion, p4, SD2, update/rollback, or physical
audio/game acceptance. Frontend display/input and the RetroArch menu lifecycle
were subsequently accepted on the live probe as recorded below.

## Host-verified implementation

- AArch64 common plumOS frontend with DRM dumb-buffer double buffering and
  page-flip completion.
- Bubble input discovery by kernel name: `retrogame_joypad` and `rk805 pwrkey`.
- Bubble physical labels: `BTN_EAST` is FE A and `BTN_SOUTH` is FE B.
- RetroArch `v1.22.2` at
  `69a4f0ea1e8aaf442ae4858f2e7f2b31a1776576`, with 13 plumOS DRM/input/audio
  patches, software plain DRM, RGUI, ALSA, and udev.
- QuickNES at `058d66516ed3f1260b69e5b71cd454eb7e9234a3`.
- RetroArch has no ELF dependency on EGL, GLES, GBM, or GL.
- Frontend and emulator library paths are scoped to their launchers; no global
  system `LD_LIBRARY_PATH` is installed.
- RK817 setup is guarded by exact mixer-control discovery before selecting
  `Resume Path=ON`, `Playback Path=SPK`, and conservative `SPK=40%`.
- Frontend, RetroArch menu, and game launch are foreground-owned sessions.
  The FE releases DRM/input before a child and reacquires them after return.
- The common START menu retains UI Settings, System Settings, Network Settings,
  Apps, Help, Reboot, and Shutdown. Incomplete device support remains visible
  and reports its state instead of being hidden from the menu.
- Bubble input discovery uses `/sys/class/input/input*/name` and event symlinks.
  BusyBox `ash` blocked before the first line when reading
  `/proc/bus/input/devices` on this runtime, so that procfs parser is not used.
- `/storage/plumos/logs/frontend-actions.log` records action, before/after
  screen, cursor, menu, and status in addition to the raw input-event trace.
- Mutable settings are seeded only when missing. ROM, BIOS, save, state, and
  user configuration paths are excluded from managed app-layer checksums.
- No ROM or BIOS content exists in the image.

## Diagnostic stages

The previously proven `S10..S39` path remains intact. New stages are:

| Stage | Meaning |
|---|---|
| `S39_APP_LAYER_VERIFIED` | Complete managed app-layer checksum passed |
| `S40_FRONTEND_SUPERVISOR_READY` | Audio guard completed and supervisor is ready |
| `S41_FRONTEND_START` | FE process is about to start |
| `E39_*` | App metadata/checksum failure; recovery console and SSH remain |
| `E40_AUDIO_INIT_FAILED` | Audio helper returned failure; FE still proceeds |
| `E80_FRONTEND_EXIT` | FE exited; return code and attempt are logged |
| `E81_FRONTEND_RESTART_LIMIT_RECOVERY_CONSOLE` | Five FE failures; stop restarting and retain console/SSH |
| `S60..S69` | RetroArch standalone menu begin/end |
| `S70..S79` | QuickNES game session begin/end |

Persistent evidence is written below `/storage/plumos/logs`; FE input events
and DRM frame statistics are enabled for the first physical boot.

## Host gates run

- component and app-layer SHA-256 verification
- JSON parsing and script syntax checks
- AArch64 ELF checks for FE, RetroArch, and QuickNES
- AArch64 RetroArch runtime smoke test: version `1.22.2`, UDEV, ALSA, and
  dynamic libretro-core loading enabled
- scripted text-renderer FE navigation
- FAT `fsck.fat -vn` and ext4 `e2fsck -fn`
- raw prefix, exact p1/p2/p3 geometry, System A/B, p2 hash, initramfs, and DTB
  readback
- base and personalized-image full SHA-256 readback
- personalized WPA configuration mode `0600` and byte-for-byte readback

## Accepted host artifact

- implementation source: `eee3d8c`
- private image:
  `plumOS-Bubble-0.1.0-dev-frontend-retroarch-probe-wifi-private.img`
- bytes: `2231369728`
- SHA-256:
  `3cf4f1dbd7eeaae3e68442d16a9f3784c23926341e6479f0cd8fe2cc8c5f9eb8`
- base image SHA-256:
  `75e25dc2aca3a18b693ed85974481cde06b041466a245c58f78d486529efa9b8`
- status: host accepted and FE/RetroArch-menu physically accepted, private,
  diagnostic-only, not publishable

Both the base and Wi-Fi-personalized images passed the independent image
verifier. Only the personalized image and its sidecars are retained under
`output`; superseded images were moved to the macOS Trash after verification.

## Physical acceptance state

1. Passed: common plumOS logo transitions to the graphical frontend.
2. Passed for FE and RGUI: D-pad, physical A, and physical B respond. A full
   button-map and standalone-emulator pass remains.
3. Partially passed: START -> Apps -> RetroArch opens RGUI; Select+Start exits
   and exactly one FE instance returns. F/Mode menu toggle remains.
4. Pending: user-provided NES content, QuickNES video/input/audio, audible
   speaker/headphone output, save/state, and return-to-FE.
5. Passed: SSH remains reachable; app-layer and fatal kernel-log checks pass.
6. Pending: FE-menu shutdown and, only if another SD insertion is necessary,
   FAT/ext4 clean-state readback.

## Physical results on the live probe

- Common logo -> FE: passed.
- START menu: the seven common entries are present; Apps is the fourth entry.
- FE input and action routing: passed with persistent raw/action traces.
- RetroArch RGUI: passed after correcting the exact
  `rgui_show_start_screen = "false"` setting. The earlier unrecognized
  `menu_show_start_screen` spelling left RetroArch in its first-boot fallback.
- RetroArch runtime ownership: DRM card0, controller event2, and ALSA
  `pcmC0D0p` are held by the RetroArch process. The Bubble udev fallback
  configured `retrogame_joypad` in port 1.
- RGUI D-pad/A/B and SELECT+START exit: physically passed. RetroArch exited
  with `rc=0`; one FE process reacquired DRM, controller event2, and power
  event0.
- App-layer checksum, Wi-Fi/SSH, and fatal kernel-log scan: passed after the
  final live deploy. Active frontend/system/RetroArch/WPA settings were
  preserved across managed-file deployment.
- Remaining: F/Mode menu toggle, QuickNES with user-provided content, audible
  speaker/headphone output, save/state persistence, and first-boot
  provisioning/update layout.
