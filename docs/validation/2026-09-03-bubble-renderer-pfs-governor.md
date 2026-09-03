# Bubble renderer audit and PFS governor comparison (2026-09-03)

## Scope

This check followed the report that Pyxel performance was below the other
plumOS RK3566 targets. It first separated an actual software renderer from a
CPU governor or frame-pacing problem. Persistent and runtime volume, including
the ALSA softvol raw value, remained `0`. The validation copy of
`pfs.pyxapp` had SHA-256
`477bb1ed3809344daae8dda0890197582e0f99c4c4e0db70bc6ca50d2f7e2ba3`.
The supplied ROM and its user settings were not modified.

## Renderer audit

The live Pyxel process mapped Bubble's captured
`/storage/plumos/emulator/lib/libmali.so.1`, owned `/dev/mali0` and
`/dev/dri/card0`, and mapped none of `kms_swrast`, `swrast_dri`, or LLVM.
Its runtime log reported `backend=kmsdrm api=gles2`. The observed problem is
therefore not Pyxel executing through Mesa software GL.

Two real fallback hazards nevertheless existed in the managed source:

- the Pyxel package carried Mesa EGL/GLES, LLVM and `kms_swrast_dri.so` and
  would silently use them if the vendor path failed;
- PortMaster globally exported `LIBGL_ALWAYS_SOFTWARE=1` and selected
  `kms_swrast`, including for ports that own their rendering policy.

The Pyxel package now requires `/dev/mali0` and the single Bubble Mali DSO for
EGL and GLES and contains no Mesa fallback payload. PortMaster GUI has the same
hardware requirement. Individual ports are hardware-preferred and retain
ownership of any title-specific renderer override. RetroArch's classic CPU
cores and PicoArch's CPU framebuffer plus DRM presentation remain intentional
software emulation paths, not accidental Mesa fallbacks. The six packaged
RetroArch GLES cores remain hardware routes.

## PFS comparison

PFS prefers a writable config beside its `.pyxapp`, so a fresh `HOME` alone
was not an isolated test. The first pilot run read an existing
`pfs_config.json` with `fps_limit=30` and is excluded. The final comparison set
used a private `PFS_CONFIG_DIR` and the same minimal config with
`fps_limit=60`, detail 2 and 4:3 aspect for every 20-second run. PFS automatic
30fps tuning was thereby disabled; the only intended difference was the CPU
governor. Runs were ordered performance, ondemand, ondemand, performance.

| Governor/run | swap FPS mean | CPU frequency | process CPU | GPU load | temperature |
|---|---:|---:|---:|---:|---:|
| performance-1 | 56.43 | 1992 MHz, 100% samples | 72.1% | 11.2% | 45.6–47.8 C |
| ondemand-1 | 29.16 | 1390.6 MHz mean | 65.4% | 5.4% | 45.0–48.3 C |
| ondemand-2 | 28.74 | 1346.8 MHz mean | 65.4% | 5.3% | 45.0–47.2 C |
| performance-2 | 36.58 | 1992 MHz, 100% samples | 50.8% | 6.6% | 46.7–48.9 C |

All steady-state samples mapped Mali, none mapped software GL, ALSA remained
`RUNNING`, and the GPU stayed at 200 MHz. `ondemand` reached 1992 MHz in only
29–35% of samples and reproducibly delivered about 29fps. `performance`
delivered 36.58–56.43fps, a 26–97% improvement over the ondemand runs. The two
performance runs also show that the governor alone does not guarantee a stable
60fps; follow-up should profile the remaining application/frame-pacing
variance rather than add a software renderer or silently lower global quality.

With a truly empty PFS config, both ondemand runs detected less than 45fps and
saved `fps_limit=30`. The first performance run sustained 53–56fps and did not
create that downgrade; a later performance run crossed the application's
threshold and did. Existing PFS settings are therefore preserved rather than
rewritten by plumOS.

## Applied policy and recovery

Pyxel now defaults to `performance` only for the lifetime of its launcher. The
launcher snapshots every CPU policy before the game and restores the previous
governor on normal exit or a bounded signal path. RetroArch, PicoArch,
standalone routes and the frontend keep their existing defaults.

The SSH harness stopped the frontend repeatedly and consumed the early init
four-attempt frontend restart limit. After logs were captured, `sync` followed
by a forced reboot restored the normal frontend. This is a harness lifecycle
limitation, not a normal one-game FE route. Post-reboot acceptance requires one
frontend process, `ondemand`, volume zero, no stale game process, and valid
managed checksums.
