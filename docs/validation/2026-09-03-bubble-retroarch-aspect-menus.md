# Bubble RetroArch aspect and menu validation

Date: 2026-09-03  
Implementation: `52d5726`, `d6ab07a`  
Deployed app-layer source: `d47e3d9`

## Reported failure and root cause

With the Game Gear Genesis Plus GX route running, the old DRM log initially
reported a 640x480 content surface. Enabling integer scale created a 576x432
RGUI surface, while the already allocated content surface retained its old
dimensions. Bubble's plain-DRM backend scales into viewport-sized dumb
buffers, so changing only the cached aspect or KMS plane could not apply an
aspect/integer-scale change to the game. RGUI also inherited the running
core's aspect and integer-scale setting instead of the 640x480 panel contract.

This is the same stale surface/viewport class previously corrected on Pixel2,
adapted here without Pixel2's portrait-panel rotation.

## Implementation

- The final game viewport is computed from the post-rotation per-surface
  Core Provided aspect.
- Runtime aspect and video-state changes invalidate both dumb-buffer surfaces;
  the next content/menu frame recreates them with the new dimensions.
- Integer scale applies only to the content layer. RGUI always uses the full
  landscape 4:3 panel, including its first frame.
- RGUI input-dimension changes recreate its surface rather than copying through
  stale frame dimensions or pitch.
- Factory defaults explicitly retain `aspect_ratio_index = "22"` and
  `video_aspect_ratio_auto = "true"` (Core Provided).

Bubble had also compiled out XMB and Ozone and shipped no assets for them.
Parity with MF/Pixel2 now includes the three menu drivers RGUI, XMB and Ozone,
official assets pinned at retroarch-assets commit
`73106363e14e34c08a5854b4cfbc29f184e3b783`, and Japanese fallback fonts.
RGUI remains the default and uses plain DRM. An explicit XMB/Ozone selection
uses the existing vendor-Mali KMS/EGL/GLES route for both menu and game.

## Host verification

- RetroArch v1.22.2 AArch64 build: passed.
- Menu symbols: `menu_ctx_rgui`, `menu_ctx_xmb`, `menu_ctx_ozone` present.
- Display-contract, 3,376-key cfg, menu-asset and launcher fixtures: passed.
- Official menu assets: 6,999 files, approximately 99 MiB.
- Complete app-layer assembly and catalog/core load checks: passed.
- RetroArch binary SHA-256:
  `5753ffef29fdde6c4a62ba614fe27f084d675cec180d5a7ac5fb79629fe3d9c8`.

## Managed device deployment

The existing running game was terminated through its launcher. The active cfg
SHA-256 remained
`e3236781903ef806f8e3c4fc7611a6093f541b3d8dc0fe49d4724f050bfdb02c`
before and after termination and deployment. ROM, BIOS, saves, states and
mutable settings were not replaced.

All 7,010 staged files matched host hashes before switching. Pre-switch checks
passed RetroArch 110/110 and app-layer 4,947/4,947. Post-switch checks passed:

- frontend: 147/147;
- RetroArch: 7,111/7,111;
- complete app layer: 11,948/11,948.

Rollback archive:

`state/update-rollback/cf99f17-to-d47e3d9-ra-display-20260903T145019JST.tar`

SHA-256:
`c6e3d55041496cdbded5da9872164715ae406d9b14637894509f9e9ff9030662`

The adjacent `.added-paths` record identifies the new asset paths that must be
removed before extracting the archive during a rollback.

## Device probes

The same Game Gear content and Genesis Plus GX core produced these explicit
plain-DRM contracts from isolated cfg copies:

```text
Core Provided: viewport=640x480+0+0 scanout=640x480 aspect=1.333333
Integer scale: viewport=576x432+32+24 scanout=576x432 aspect=1.333333
RGUI + integer scale: layer=2 viewport=640x480+0+0 scanout=640x480
```

XMB and Ozone each initialized vendor Mali EGL 1.4, KMS, 640x480 framebuffers,
the managed ALSA device and their graphical menu pipeline without a crash.
The original frontend PID 441 was stopped only with `SIGSTOP` during these
bounded probes and resumed with `SIGCONT`; it remained the sole frontend
process. CPU governors returned `ondemand` and persisted volume remained zero.

Physical LCD acceptance is intentionally still open: repeat the reported game,
toggle integer scale, open/close RGUI, then separately restart with XMB and
Ozone and check visible geometry, text/icons, controls, audio and resume.
