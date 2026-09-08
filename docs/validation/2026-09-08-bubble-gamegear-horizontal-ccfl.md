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

## B2 without general STN desaturation live experiment

The complete preceding state was first committed as `117f7e0` and tagged
`shader-sega-hccfl-b2`. The device copy of its panel shader was also backed up
and hash-verified at:

```
/storage/plumos/state/shader-backups/20260908-sega-hccfl-b2/gamegear-lcd-panel.glsl.SEGA-HCCFL-B2.0744f57f
0744f57ff36af4568490073bde1dbbd4f5cff45d728dcc1ebf77705abe92267f
```

For the requested experiment, only the general STN saturation factor
`gg_sat` was changed from 0.55 to 1.00. The blue-specific
`gg_bluesat=1.20` and `gg_blueweak=0.15`, temporal response, directional row
invasion, CCFL field, RGBK apertures and optics pass all remain enabled.

The launcher contract passed. The normal frontend was the sole display owner;
no emulator, standalone application or GGFE process was running. Incoming,
final and host readback hashes matched:

```
877cabde95adec59d1fb130b78a31f5e4fcbbd72a225184249fe0b69c4091172
```

The incoming path was consumed by the atomic rename. The mutable shader is not
covered by `/mnt/plumos/checksums.sha256`; no managed metadata or other
frontend component was changed. No reboot was required. Physical comparison
against B2 remains pending.

## B2 general saturation 0.85 live experiment

After comparing B2 saturation 0.55, intermediate 0.85 and desaturation-off
1.00 under the same source and geometry, the intermediate value was selected
for physical inspection. Only `gg_sat` changed from 1.00 to 0.85; all other B2
panel, colour, response and optics values remain unchanged.

The preceding 1.00 device shader was backed up and hash-verified at:

```
/storage/plumos/state/shader-backups/20260908-b2-sat085/gamegear-lcd-panel.glsl.sat100.877cabde
877cabde95adec59d1fb130b78a31f5e4fcbbd72a225184249fe0b69c4091172
```

The launcher contract passed. The normal frontend was the sole display owner;
no emulator, standalone application or GGFE process was running. Incoming,
final and host readback hashes matched:

```
da933d082861d50291e27caa819f5c9eb25eb3b292cf7a51ff4dc2a704391b8b
```

The incoming path was consumed by the atomic rename. The mutable shader is not
covered by `/mnt/plumos/checksums.sha256`; no managed metadata or other
frontend component was changed. No reboot was required. Physical comparison
against B2 and saturation 1.00 remains pending.

## B2 saturation 0.85 with extreme temporal ghost live experiment

To make the temporal response unmistakable before tuning it downward, only
the response speeds were changed: `gg_rise` from 0.62 to 0.20 and `gg_fall`
from 0.34 to 0.05. This retains 80% of the four-frame history on a dark-to-
light transition and 95% on a light-to-dark transition. The history weights
remain 42/28/18/12 percent. The B2-derived panel shader, including saturation
0.85, blue fit, RGBK separator and spatial row invasion, remains unchanged.

The preceding B2 response shader was backed up and hash-verified at:

```
/storage/plumos/state/shader-backups/20260908-b2-extreme-ghost/gamegear-lcd-response.glsl.rise062-fall034.3cf9ec82
3cf9ec8273ed49f106c94f0e104842449658b2faac9bf6c04fbf662bbeb5a6a6
```

The launcher contract passed. The normal frontend was the sole display owner;
no emulator, standalone application or GGFE process was running. Incoming,
final and host readback response-shader hashes matched:

```
7f1b9e4997ccc6cf3d8fb9f0cb365ffae484e51b29be37e5cdb09b16536fa8a1
```

The active panel shader remained the saturation 0.85 version with hash
`da933d082861d50291e27caa819f5c9eb25eb3b292cf7a51ff4dc2a704391b8b`.
No reboot was required. Physical motion acceptance remains pending.

## B2 saturation 0.85 with 100% bright peak-hold live experiment

The speed-only experiment above was visible but did not produce a sufficiently
strong afterimage on the Bubble. For a deliberately destructive diagnostic,
`gg_peak_hold=1.00` now preserves the brightest per-channel value found in the
four-frame history whenever the current transition is light-to-dark. The
asymmetric response remains extreme (`gg_rise=0.20`, `gg_fall=0.05`), so a
moving bright object can leave up to four near-full-brightness silhouettes.
This is intentionally an upper-bound experiment rather than a final STN fit.

The preceding speed-only response shader was backed up and hash-verified at:

```
/storage/plumos/state/shader-backups/20260908-b2-peak-hold100/gamegear-lcd-response.glsl.speed-only.7f1b9e49
7f1b9e4997ccc6cf3d8fb9f0cb365ffae484e51b29be37e5cdb09b16536fa8a1
```

The normal frontend was the sole display owner during deployment. Incoming,
final and host readback response-shader hashes matched:

```
7e42fe55b3310563d78e3bdc93a33a1689fad55b39a254fcf82fcdf0b9bd63b3
```

The active panel shader remained unchanged at the B2-derived saturation 0.85
hash `da933d082861d50291e27caa819f5c9eb25eb3b292cf7a51ff4dc2a704391b8b`.
The incoming path was consumed by the atomic rename. No reboot was required.
Physical motion acceptance remains pending.

## B2 saturation 0.85 with smooth twelve-frame feedback experiment

The four-frame 100% peak hold above looked like panel flicker and reduced the
perceived trail. It was replaced with pass-0 feedback: the response pass now
reads its own preceding output through `FeedbackTexture`, enabled by
`feedback_pass = "0"` in the full preset. This is required because RetroArch's
GLSL raw-input history only exposes `PREV` through `PREV6`, fewer than the
requested twelve frames.

Peak hold was removed and the B2 light-rise speed was restored to 0.62. A
bright-to-dark transition now decays continuously to ten percent after twelve
frames (about 200 ms at 60 Hz), with no fixed-frame cutoff. The host model
measured 0.1212 remaining in each RGB channel at the oldest test position after
eleven decay steps; the difference from exactly 0.10 is the sequence indexing,
not a channel imbalance.

The preceding peak-hold response and non-feedback preset were backed up and
hash-verified at:

```
/storage/plumos/state/shader-backups/20260908-b2-feedback12/gamegear-lcd-response.glsl.peak-hold100.7e42fe55
7e42fe55b3310563d78e3bdc93a33a1689fad55b39a254fcf82fcdf0b9bd63b3
/storage/plumos/state/shader-backups/20260908-b2-feedback12/gamegear-lcd.glslp.no-feedback.4b259374
4b25937456e7ebff6f6e586e097b138a4d4565c7c2ec30991e82a2a16347a3ac
```

Incoming, final and host readback hashes matched:

```
02485188f6eb1b15a48f8703d4d702e7c6a448b16d661ee8895cc1d69ca735b5  gamegear-lcd-response.glsl
0e834077aaf445a98a0afcb2d2e65888bdbe35da59e0d5e1de0cbaeda03c3e5a  gamegear-lcd.glslp
```

The normal frontend was the sole display owner during deployment. The active
panel shader remained unchanged at the B2-derived saturation 0.85 hash
`da933d082861d50291e27caa819f5c9eb25eb3b292cf7a51ff4dc2a704391b8b`.
No reboot was required. Device shader compilation and physical motion
acceptance remain pending until a Game Gear title is launched by the normal
frontend route.

## B2 saturation 0.85 with smooth nine-frame feedback experiment

The twelve-frame feedback experiment produced the intended visible trail and
was shortened at the user's request without changing the response model. Only
`gg_trail_frames` changed from 12.0 to 9.0. Peak hold remains disabled, rise
speed remains 0.62, and a bright-to-dark transition now decays smoothly to ten
percent after nine frames (about 150 ms at 60 Hz). The host model measured
exactly 0.1000 remaining in every RGB channel after nine decay steps.

The preceding twelve-frame response was backed up and hash-verified at:

```
/storage/plumos/state/shader-backups/20260908-b2-feedback9/gamegear-lcd-response.glsl.feedback12.02485188
02485188f6eb1b15a48f8703d4d702e7c6a448b16d661ee8895cc1d69ca735b5
```

Incoming, final and host readback hashes matched:

```
8ea3e502a174aee22b1c4b7e02ad72f74aaae65c5abcbcd6c9d18171e31249a4
```

Only the response shader was deployed. The feedback preset remained at hash
`0e834077aaf445a98a0afcb2d2e65888bdbe35da59e0d5e1de0cbaeda03c3e5a`
and the B2-derived saturation 0.85 panel shader remained at hash
`da933d082861d50291e27caa819f5c9eb25eb3b292cf7a51ff4dc2a704391b8b`.
No reboot was required. Physical motion acceptance remains pending.

## B2 saturation 0.85 with finite nine-frame feedback experiment

The exponential nine-frame experiment could leave a visible remainder through
long dark holds during scene transitions: nine frames meant ten percent raw
response, not zero, and the panel brightness curve amplified that remainder.
The response now stores each falling pixel's age in feedback alpha and uses a
finite quadratic envelope `((N-n)/N)^2`. It retains 79.01, 60.49 and 44.44
percent over the first three frames, then 1.23 percent at frame eight and
exactly zero at frame nine. This keeps the early trail close to the preceding
experiment while guaranteeing that no pixel survives beyond the requested
nine-frame lifetime.

The preceding unbounded nine-frame response was backed up and hash-verified at:

```
/storage/plumos/state/shader-backups/20260908-b2-feedback9-finite/gamegear-lcd-response.glsl.feedback9-infinite.8ea3e502
8ea3e502a174aee22b1c4b7e02ad72f74aaae65c5abcbcd6c9d18171e31249a4
```

Incoming, final and host readback hashes matched:

```
31ef132698674e9c50c7c08508bbab39815838e034ccfedcd6fc65b41a581cfe
```

Only the response shader was deployed. The feedback preset and B2-derived
saturation 0.85 panel shader remained unchanged. The normal frontend was the
sole display owner during deployment. No reboot was required. Device shader
compilation and physical scene-transition acceptance remain pending.

## B2 saturation 0.85 with finite twelve-frame feedback experiment

The finite quadratic feedback model was retained unchanged and only
`gg_trail_frames` was increased from 9.0 to 12.0. Host simulation measured
84.03, 69.44 and 56.25 percent retention over the first three frames, 0.69
percent at frame eleven, and exactly zero at frame twelve. Unlike the earlier
unbounded twelve-frame experiment, no recursive remainder survives beyond the
configured lifetime.

The preceding finite nine-frame response was backed up and hash-verified at:

```
/storage/plumos/state/shader-backups/20260908-b2-feedback12-finite/gamegear-lcd-response.glsl.feedback9-finite.31ef1326
31ef132698674e9c50c7c08508bbab39815838e034ccfedcd6fc65b41a581cfe
```

Incoming, final and host readback hashes matched:

```
474731b8c6a4f81e2649705f72a5fa5c8e2001beb25daf35147bd2322ddcc66f
```

Only the response shader was deployed. The feedback preset and B2-derived
saturation 0.85 panel shader remained unchanged. The normal frontend was the
sole display owner during deployment. No reboot was required. Device shader
compilation and physical scene-transition acceptance remain pending.

## Finite twelve-frame static-settle correction

Physical inspection found that a stationary image could continue to look as
if its trail were moving. The cause was reproduced mechanically: pass 0 is an
RGBA8 feedback target while the core commonly supplies RGB565. The former
`1/1024` comparison threshold was smaller than the conversion error, falsely
restarting the falling-age counter for 8 of 32 red/blue levels and 15 of 64
green levels.

The response now treats an absolute RGB difference below `2/255` as settled
and snaps every channel to the current source value. Exhaustive host checks of
all RGB565 channel levels found zero false restarts and zero settled residual.
Real transitions retain the same finite quadratic curve and still reach
exactly zero on frame twelve.

The preceding finite twelve-frame response was backed up and hash-verified at:

```
/storage/plumos/state/shader-backups/20260908-b2-feedback12-settle/gamegear-lcd-response.glsl.feedback12-no-settle.474731b8
474731b8c6a4f81e2649705f72a5fa5c8e2001beb25daf35147bd2322ddcc66f
```

Incoming, final and host readback hashes matched:

```
2c1c82437767791933398b9fea8048f38e97b4487b3f2fbc7fea9b8dfef7fbfa
```

Only the response shader was deployed. The normal frontend was the sole
display owner at deployment time; the feedback preset and panel shader were
unchanged. No reboot was required. Physical stationary-image acceptance
remains pending.

## SEGA-HCCFL-B3 final acceptance

The user physically accepted the corrected finite twelve-frame response: the
trail looked appropriate during motion and stopped after the picture became
stationary. The five active device shader/preset files were read back and
matched the host B3 hashes recorded in
`docs/gamegear-lcd-shader-baselines.md`. The frontend was the sole DRM owner
after the game returned.

During ten seconds of normal FE-launched Game Gear play, RetroArch used 10.9%
CPU on average and 16% at peak; the whole CPU remained 84% idle on average.
The shared RK3566 CPU policy stayed on `ondemand` and moved between 1.104 and
1.992 GHz, reaching its configured maximum under higher load. SoC temperature
peaked at 52.5 C and GPU temperature at 54.4 C. I/O wait remained zero and the
kernel log contained no thermal, overheating or cpufreq error. No performance
governor override is required for this shader.

This accepted state is named **SEGA-HCCFL-B3** and is fixed by the annotated
Git tag `shader-sega-hccfl-b3`.
