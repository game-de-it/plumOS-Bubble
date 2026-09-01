# Bubble frontend / RetroArch probe host validation (2026-09-02)

## Scope

This gate advances the already booted external-initramfs three-partition probe
to a common plumOS frontend and a software-only RetroArch/QuickNES baseline.
It does not finalize partition expansion, p4, SD2, update/rollback, or physical
display/input/audio acceptance.

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

- implementation source: `dc9cdb0`
- private image:
  `plumOS-Bubble-0.1.0-dev-frontend-retroarch-probe-wifi-private.img`
- bytes: `2231369728`
- SHA-256:
  `1d61811996aa11242fd9eeb810fd6b62fe1c841a8f0ce2fa4949bae4a3f236cd`
- base image SHA-256:
  `51f6d37465025686caf7bf3b159222c473eaedb54c2aadf2c6f4f52ce137e966`
- status: host accepted, private, diagnostic-only, not publishable

Both the base and Wi-Fi-personalized images passed the independent image
verifier. Only the personalized image and its sidecars are retained under
`output`; superseded images were moved to the macOS Trash after verification.

## Required physical acceptance on the next boot

1. Common plumOS logo transitions to the graphical frontend, not a shell.
2. D-pad moves once per press; physical A confirms and physical B returns.
3. START -> Apps -> RetroArch opens RGUI; the F/Mode button opens/closes its
   menu; Select+Start exits and FE returns once.
4. Speaker output is audible at a safe level after launching user-provided NES
   content; QuickNES video/input/audio and return-to-FE are checked.
5. SSH remains reachable and logs show no `E39`, DRM failure, kernel Oops,
   panic, I/O error, or repeated `E80`.
6. Shutdown from the FE menu completes before power is removed. FAT/ext4 clean
   state is checked at the next host readback only if another SD insertion is
   still necessary.

The first physical boot may prove or reject the inferred RetroArch button
indices. The persistent FE input trace makes a correction possible over SSH,
without another SD-card swap.
