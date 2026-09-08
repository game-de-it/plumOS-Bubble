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

## B1 + RowGap0 candidate deployment

After the user compared an enlarged B1 preview with an enlarged SEGA panel
photograph, the horizontal row matrix was removed while every other B1 value
was retained.  The candidate changes `gg_rowgap` from 0.80 to 0.00.  The
immutable `shader-sega-hccfl-b1` tag remains the comparison and rollback
baseline.

Host previews are under
`output/preview/gamegear-lcd-sega-photo-fit/b1-no-horizontal-gap/`.  Python
preview compilation, `git diff --check` and
`tests/test-bubble-retroarch-launch.sh` passed before deployment.

No emulator or GGFE process was running.  The normal
`plumos-controller-ui-fbdev` process remained the sole display-device owner
and was not stopped.  The B1 file was backed up and verified at:

```
/storage/plumos/state/shader-backups/20260908-b1-rowgap0/gamegear-lcd-panel.glsl.SEGA-HCCFL-B1.69c7970f
```

The candidate was staged, device-hashed, synced, atomically renamed, synced
again and read back to the host.  All copies matched:

```
3fac80ec98ab333a719656afa5510b9bd8b6e6e6b6bd6973a18ee1e3e0aeb4ad
```

Physical visual acceptance is pending.  Recheck continuous vertical aperture
columns, the remaining thin vertical black structure, perceived brightness,
`THE HEDGEHOG`, the footer, motion and normal FE return.

## B1-R0-V100 explicit-line deployment

Because RowGap0 produced little visible change on the physical Bubble, an
intentionally extreme vertical-line diagnostic was added on top.  At the exact
4x horizontal scale it forces the last one of every four output pixels dark:
one 100%-strength output-pixel line per logical Game Gear cell.  This is wider
and darker than the target panel feature; its purpose is to establish the
correct phase and period before reducing strength or modelling sub-pixel
coverage.

No colour, CCFL, STN invasion or motion parameter was changed.  Nevertheless,
the line replaces the output pixel that contains most of the blue aperture, so
spatial integration can make the image look warmer/yellower even without an
explicit colour-matrix change.  The host preview mean luminance changed from
0.4121 to 0.3383.

No emulator or GGFE process was running; `plumos-controller-ui-fbdev` remained
the sole display-device owner.  The preceding RowGap0 candidate was backed up
and hash-verified at:

```
/storage/plumos/state/shader-backups/20260908-b1-r0-v100/gamegear-lcd-panel.glsl.B1-RowGap0.3fac80ec
```

The VLine100 candidate was staged, device-hashed, synced, atomically renamed,
synced again and read back to the host.  All copies matched:

```
8e5859afaa32e35df5dcac8099633b01c844ef44fe7abdb65b1ee7db144e1e34
```

Physical acceptance is pending.  The first decision is whether one line per
four output pixels has the same period and phase as the real SEGA panel.  Its
strength, width, colour balance and overall luminance are deliberately not
acceptance targets at 100%.

## B1-R0-V2PX100 deployment

The one-output-pixel VLine100 diagnostic was not perceptible on the physical
Bubble.  The line period and strength were retained, but its width was doubled:
the final two pixels of every four-pixel logical cell are now forced dark.
This consumes 50% of every RGB triad and is intentionally much wider than the
target panel line.

The preceding one-pixel candidate was backed up and verified at:

```
/storage/plumos/state/shader-backups/20260908-b1-r0-vline2px100/gamegear-lcd-panel.glsl.B1-R0-V100.8e5859af
```

The two-pixel candidate passed preview synchronization and the RetroArch
launcher contract, then was staged, device-hashed, synced, atomically renamed,
synced again and read back to the host.  All copies matched:

```
6a8a1ad8c61026fc9fc19ede4b130e79342b54483e1ebe8132582f221f61fe4f
```

No emulator or GGFE process was running and the normal frontend remained the
sole display owner throughout.  Physical visibility and period comparison are
pending.

## B1-R0-P480-G18 host preview

The two-output-pixel diagnostic established that a vertical line can alter the
physical Bubble image, but its 160-line/four-output-pixel coordinate system is
not the SEGA LCD element lattice. This preview-only candidate instead models
three vertical filter elements for each of the 160 colour columns:

```
physical element columns = 160 * 3 = 480
Bubble pixels per element = 640 / 480 = 4 / 3
black boundary width      = 18% of one physical element pitch
```

The boundary is integrated over each Bubble output-pixel footprint with
`periodic_box_coverage`; no literal one- or two-pixel line is drawn. Its mean
transmission is normalised to one so this comparison does not repeat the
yellow cast caused by deleting the G/B half of the former four-pixel cell.

The Sonic 2 source was recovered from the exact unfiltered 640x480 nearest-
neighbour reference previously used for the H-CCFL comparison. Outputs:

```
output/preview/gamegear-lcd-sega-photo-fit/b1-physical480-gap18/lcd-on.png
output/preview/gamegear-lcd-sega-photo-fit/b1-physical480-gap18/comparison-full.png
output/preview/gamegear-lcd-sega-photo-fit/b1-physical480-gap18/comparison-macro.png
```

The full comparison is ordered B1-R0 without the explicit diagnostic, the
160-period/two-pixel diagnostic, then the recommended 480-element candidate.
The macro comparison uses the same order from top to bottom. The launcher
contract passed. This candidate has **not** been deployed to the Bubble;
physical acceptance remains pending.

## B1-R0-RGBK25 host preview

A second macro photograph showed one dominant luminance trough for each full
colour cycle, not one trough at every R/G/B element boundary. The working
physical model was therefore corrected from the P480 candidate to four equal
optical bands per 160-dot colour column:

```
R 25% | G 25% | B 25% | black separator 25%
```

The B filter remains active. Because blue has low apparent luminance and is
adjacent to the major black separator, optical crosstalk makes the two read as
one broad dark band. Fine filter boundaries remain represented by `gg_elemgap`
but are softened by the optics pass, matching their weak visibility in the
photograph.

The candidate is scaled to match B1's final post-exponential mean luminance,
not merely its linear input transmission. On the Sonic reference:

```
B1-R0  luma = 0.412131
RGBK25 luma = 0.412125
```

Outputs are under:

```
output/preview/gamegear-lcd-sega-photo-fit/b1-rgbk25/
```

`comparison-full.png` is ordered B1-R0, P480-G18, RGBK25 from left to right;
`comparison-macro.png` uses the same order from top to bottom. The RetroArch
launcher contract passed.

## B1-R0-RGBK25 live shader deployment

After host preview acceptance, only the mutable live panel shader was updated;
no frontend component, launcher, preset or app-layer metadata was deployed.
Before the update the normal frontend was the sole display owner and no
RetroArch, PicoArch, standalone emulator or GGFE process was running.

The preceding two-pixel diagnostic was backed up and verified at:

```
/storage/plumos/state/shader-backups/20260908-b1-rgbk25/gamegear-lcd-panel.glsl.B1-R0-V2PX100.6a8a1ad8
6a8a1ad8c61026fc9fc19ede4b130e79342b54483e1ebe8132582f221f61fe4f
```

RGBK25 was copied to an incoming path, device-hashed, synced, atomically
renamed, synced again and read back to the host. Source, incoming, final and
readback copies matched:

```
b46878dd81f52b1bf7c0c5d80052e63fb80e326f6acfbabc7e4efb8a1e70c134
```

The incoming file was removed by the rename. The mutable shader has no entry
in `/mnt/plumos/checksums.sha256`, so no managed app-layer metadata needed to
change. Physical Game Gear launch and visual acceptance remain pending.

## B1-R0-RGBK25-B20 host preview

To test whether the photographed B aperture and adjacent major separator read
as a two-output-pixel dark trough, the B optical band alone was reduced to 20%
transmission. This does not remove blue from the whole image; only the one-pixel
B aperture in each `R/G/B/K` group is darkened. The K aperture retains the
existing backlight leakage.

The nonlinear output-match scalar was recalibrated so overall brightness did
not become the comparison variable:

```
RGBK25     luma = 0.412125
RGBK25-B20 luma = 0.412162
```

Outputs are under:

```
output/preview/gamegear-lcd-sega-photo-fit/b1-rgbk25-b20/
```

`comparison-full.png` is ordered RGBK25 then RGBK25-B20 from left to right;
`comparison-macro.png` uses the same order from top to bottom. The launcher
contract passed. This candidate is preview-only and has not been deployed.

## B1-R0-RGBK25-B20-K0 host preview

The 12% K-band transmission in the B20 preview represented direct backlight
leakage through the major separator. To test the alternative hypothesis that
the separator material itself is opaque, its direct transmission was reduced
to zero. Any light visible in K now comes only from the subsequent optical
crosstalk pass. The neighbouring B aperture remains at 20%, producing a strong
two-output-pixel trough without erasing B completely as the earlier V2PX100
diagnostic did.

The output-match scalar was recalibrated so the stronger black separator did
not lower overall image brightness:

```
B20-K12 luma = 0.412162
B20-K0  luma = 0.412209
```

Outputs are under:

```
output/preview/gamegear-lcd-sega-photo-fit/b1-rgbk25-b20-k0/
```

The comparisons are ordered B20-K12 then B20-K0 from left to right or top to
bottom. The launcher contract passed. This candidate is preview-only and has
not been deployed.

## B1-R0-RGBK25-B20-K0 live shader deployment

After preview acceptance, the RetroArch launcher contract was rerun and passed.
Only the mutable live panel shader was updated. The normal frontend was the
sole display owner; no RetroArch, PicoArch, standalone emulator or GGFE process
was running.

The preceding RGBK25 live shader was backed up and verified at:

```
/storage/plumos/state/shader-backups/20260908-b1-rgbk25-b20-k0/gamegear-lcd-panel.glsl.RGBK25.b46878dd
b46878dd81f52b1bf7c0c5d80052e63fb80e326f6acfbabc7e4efb8a1e70c134
```

The K0 shader was copied to an incoming path, device-hashed, synced, atomically
renamed, synced again and read back to the host. Source, incoming, final and
readback hashes matched:

```
96258bf93c29d4284d5630835a08d31ecd011dd800b61f3ab0c076c9bbc2d51d
```

The incoming file was removed by the rename. The mutable shader is not covered
by `/mnt/plumos/checksums.sha256`, so managed app-layer metadata was unchanged.
Physical Game Gear launch and visual acceptance remain pending.

## B1-R0-RGBK25-RG85-B20-K0 host preview

Physical K0 acceptance found the separator convincing, but reducing B made the
unchanged R/G apertures visually dominant. This candidate retains B20 and K0,
reduces only the R and G optical-band transmission to 85%, and deliberately
does not renormalise that loss. Absolute brightness is left to the Bubble's
hardware backlight rather than making the R/G bands prominent again in shader
space.

```
RG100 luma = 0.412209
RG85  luma = 0.390847
```

Outputs are under:

```
output/preview/gamegear-lcd-sega-photo-fit/b1-rgbk25-rg85-b20-k0/
```

The comparisons are ordered RG100 then RG85 from left to right or top to
bottom. The launcher contract passed. This candidate is preview-only and has
not been deployed.

## B1-R0-RGBK25-RG85-B20-K0 live shader deployment

After preview acceptance, only the mutable live panel shader was updated. The
normal frontend was the sole display owner; no RetroArch, PicoArch, standalone
emulator or GGFE process was running.

The preceding RGBK25-B20-K0 live shader was backed up and verified at:

```
/storage/plumos/state/shader-backups/20260908-b1-rgbk25-rg85-b20-k0/gamegear-lcd-panel.glsl.RG100-B20-K0.96258bf9
96258bf93c29d4284d5630835a08d31ecd011dd800b61f3ab0c076c9bbc2d51d
```

The RG85 shader was copied to an incoming path, device-hashed, synced,
atomically renamed, synced again and read back to the host. Source, incoming,
final and readback hashes matched:

```
3f832b3352be705a0332c81da9e5188256f5c1eedbcf01b64866cb89288113d1
```

The incoming file was removed by the rename. The mutable shader is not covered
by `/mnt/plumos/checksums.sha256`, so managed app-layer metadata was unchanged.
No reboot was needed. Physical Game Gear launch and visual acceptance remain
pending.

## B1-R0-RGBK25-RG85-B25-K0 live shader deployment

At the user's request, the B optical-band transmission was raised by five
percentage points, from 20% to 25%. R/G remain at 85% and the K separator
remains opaque. The RetroArch launcher contract passed before deployment.

Only the mutable panel shader was updated. The normal frontend was the sole
display owner; no emulator, standalone application or GGFE process was
running. The preceding RG85-B20-K0 shader was backed up and verified at:

```
/storage/plumos/state/shader-backups/20260908-b1-rgbk25-rg85-b25-k0/gamegear-lcd-panel.glsl.RG85-B20-K0.3f832b33
3f832b3352be705a0332c81da9e5188256f5c1eedbcf01b64866cb89288113d1
```

Incoming, final and host readback hashes matched:

```
f090b0e5aa5a1324a8a4dc2642b69f978bb1d274484af7859e9b4fde60a1ff79
```

The incoming path was consumed by the atomic rename. The mutable shader is not
covered by `/mnt/plumos/checksums.sha256`; no managed metadata or other
frontend component was changed. No reboot was required. Physical colour and
black-separator acceptance remain pending.

## B1-R0-RGBK25-RG85-B25-K0 blue-reference host preview

The supplied 640x480 Bubble capture was treated as the colour target, with the
large pure-blue source regions weighted ahead of the title artwork. To avoid
confusing the accepted aperture geometry with colour, target and candidate
pixels were averaged over the source-blue mask. The selected candidate changes
only the STN colour response: black floor 0.14 to 0.12, blue-region saturation
0.90 to 1.20, and blue-to-green leakage 0.14 to 0.15. B25, RG85 and K0 remain
unchanged.

```
target blue mean RGB    = 46.679 75.641 116.231
candidate blue mean RGB = 47.456 74.517 116.099
```

The resulting absolute per-channel errors are below 1.2 levels on an 8-bit
scale. Outputs are under:

```
output/preview/gamegear-lcd-sega-photo-fit/b1-rgbk25-rg85-b25-k0-blue-fit-final/
```

The launcher contract passed. It remained preview-only until the deployment
recorded below.

## B1 blue-reference live shader deployment

After preview acceptance, only the mutable panel shader was deployed. The
normal frontend was the sole display owner; no emulator, standalone
application or GGFE process was running. The preceding RG85-B25-K0 shader was
backed up and verified at:

```
/storage/plumos/state/shader-backups/20260908-b1-blue-reference-fit/gamegear-lcd-panel.glsl.RG85-B25-K0-before-blue-fit.f090b0e5
f090b0e5aa5a1324a8a4dc2642b69f978bb1d274484af7859e9b4fde60a1ff79
```

Incoming, final and host readback hashes matched:

```
bb215b963f214bea363d4e21a3ba406a4449f4342031abb60005272b6b377254
```

The incoming path was consumed by the atomic rename. The mutable shader is not
covered by `/mnt/plumos/checksums.sha256`; no managed metadata or other
frontend component was changed. No reboot was required. Physical blue-colour
acceptance remains pending.

## B1 edge-only copyright erosion host preview

To retain the accepted K0 vertical separator and blue-reference colour while
reducing the overly clear copyright mark, the footer-specific control was
isolated from the row grid and colour controls. A sweep from edge dark invasion
0.75 through 1.00 showed that 0.90 is the smallest strong candidate: it lowers
the source-white copyright luminance by about 12.4% while leaving both the blue
field and centre title effectively unchanged.

```
                         edge 0.75   edge 0.90
copyright white luma       114.203      99.989
copyright blue luma         67.863      67.806
THE white luma             160.017     159.860
```

The candidate changes only `gg_dark_smear` from 0.75 to 0.90. `gg_rowgap`
remains zero, B/RG/K transmission and the blue-reference colour values remain
unchanged, and therefore no horizontal grid is reintroduced. Outputs are under:

```
output/preview/gamegear-lcd-sega-photo-fit/b1-rgbk25-rg85-b25-k0-blue-fit-edge90/
output/preview/gamegear-lcd-sega-photo-fit/copyright-edge-dark-sweep/
```

The launcher contract passed. It remained preview-only until the deployment
recorded below.

## B1 edge-dark90 live shader deployment

After preview acceptance, only the mutable panel shader was deployed. The
normal frontend was the sole display owner; no emulator, standalone
application or GGFE process was running. The preceding edge-dark75 blue-fit
shader was backed up and verified at:

```
/storage/plumos/state/shader-backups/20260908-b1-edge-dark90/gamegear-lcd-panel.glsl.edge-dark75.bb215b96
bb215b963f214bea363d4e21a3ba406a4449f4342031abb60005272b6b377254
```

Incoming, final and host readback hashes matched:

```
0744f57ff36af4568490073bde1dbbd4f5cff45d728dcc1ebf77705abe92267f
```

The incoming path was consumed by the atomic rename. The mutable shader is not
covered by `/mnt/plumos/checksums.sha256`; no managed metadata or other
frontend component was changed. No reboot was required. Physical copyright
erosion, blue colour and vertical-separator acceptance remain pending.
