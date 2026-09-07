# Bubble Game Gear horizontal-CCFL shader validation

Date: 2026-09-08

Physical visual acceptance after deployment established this state as the
named comparison point **SEGA-HCCFL-B1** (`SEGA Horizontal CCFL Baseline 1`).
The baseline deliberately precedes investigation of the remaining black
vertical-line characteristic.

## Scope

Replace the former point/radial backlight and STN-response field with a
horizontal line-source model, while increasing only the outer dark-row
invasion from 0.65 to 0.75.  This is a shader-only calibration deployment;
the app layer, launcher, presets, persistent RetroArch configuration and user
content are outside this update.

## Host preview

- The line source spans 76% of the panel width and uses distance to that line
  segment.  Its field is therefore capsule-shaped: predominantly vertical
  falloff across the tube body, with continuous rounded falloff beyond its
  ends.
- The illumination range was held constant while changing geometry.  The old
  radial preview measured 0.836..0.982 and the new tube preview measured
  0.838..0.982 after the shipped `gg_backlight=0.28` mix.
- Sonic 2 and Eternal Legend previews, plus actual-range and normalized
  light-only maps, are under
  `output/preview/gamegear-lcd-sega-photo-fit/horizontal-ccfl-dark075/`.
- `scripts/preview-gamegear-lcd.py` and the GLSL use the same tube length,
  physical-aspect correction, smoothstep extent and 0.75 outer dark weight.
- `git diff --check`, Python byte-code compilation and
  `tests/test-bubble-retroarch-launch.sh` passed.

## Live shader-only deployment

The device boot id was `05284794-7ade-4959-a41f-f1367492c241`.  Before the
write there was no RetroArch, PicoArch, GGFE, DraStic or PPSSPP process.  The
normal `plumos-controller-ui-fbdev` remained the sole display-device owner and
was not stopped or restarted.

The previous live shader was:

```
c679f1d0a103dbaea26d10e3483c3251e3676838d4475db9351691a6d9e5cd50
```

It was saved as:

```
/storage/plumos/state/shader-backups/20260908-horizontal-ccfl-dark075/gamegear-lcd-panel.glsl.c679f1d0
```

The incoming file was hashed on-device, synced, atomically renamed, synced
again, then read back to the host.  Device, host and readback all matched:

```
69c7970fd808fbc200b405e6bedffb432b144bff2cdf74d112e83a4d691f9926
```

The mutable live shader has no entry in `/mnt/plumos/checksums.sha256`, so no
app-layer checksum or manifest was modified.

## Remaining physical acceptance

- Launch Game Gear through the normal FE route; do not start another renderer
  over the running frontend.
- Confirm the former circular transition is absent in a flat field and in
  Eternal Legend.
- Recheck central `THE HEDGEHOG` and the outer copyright/footer glyphs.  The
  target is preserved centre-white invasion with stronger outer black
  intrusion.
- Confirm colour, motion, frame pacing, RetroArch exit and FE return.  These
  remain pending until observed on the physical LCD.
