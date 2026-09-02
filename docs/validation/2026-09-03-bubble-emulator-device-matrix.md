# Bubble emulator device matrix (2026-09-03)

## Scope and guard rails

The Bubble catalog was tested without deleting any system, emulator, core or
frontend route. The catalog remains 98 visible systems and 196 launch-profile
occurrences. Tests used bounded launches over SSH while the persistent and
runtime volume were both forced to `0`; ALSA `plumos_output` raw softvol was
also `0`. Test config, saves and states were bind-mounted to an isolated
runtime sandbox. The supplied SD2 ROM media remained read-only.

The primary report is
`artifacts/device-validation/2026-09-03-bubble-emulator-matrix-final.json`.
Clean-content recovery reports are:

- `2026-09-03-bubble-clean-cartridge-retest.json`
- `2026-09-03-bubble-emulator-focused-retest-3.json`
- `2026-09-03-bubble-pyxel-audio-retest.json`
- `2026-09-03-bubble-openbor-retest.json`
- `2026-09-03-bubble-msx-final-retest.json`

After replacing corrupt live-media samples with hash-verified validation
copies from the supplied Mac ROM set, the aggregate route state is:

| State | Route occurrences | Meaning |
|---|---:|---|
| started | 89 | process survived the bounded probe, owned DRM and exited only when stopped by the harness |
| failed | 1 | BlueMSX crashes before its first frame; fMSX is the working visible fallback |
| visible unsupported | 1 | DraStic requires the missing Bubble `/dev/miyooio` input bridge |
| not run | 105 | no compatible clean content, or an external-script route outside this emulator harness |

The 89 started routes include all routes for clean SFC, GB, GBC, GBA and N64
samples. One transient SSH failure for RetroArch VBA-M in the clean cartridge
batch is superseded by its successful bounded run in the primary matrix.

## Display contract

`scripts/verify-bubble-display-contracts.py` parses the runtime geometry rather
than inferring aspect from process liveness. Across the primary and focused
reports it validated 62 observed RetroArch/Pyxel display contracts with zero
geometry failures. Every viewport was positive, centered within 640x480,
bounded by the panel, matched the core aspect after rotation, and matched the
DRM scanout extent.

The vertical FBNeo sample reported:

```text
frame=384x256 aspect=1.333333 rotation=3
viewport=360x480+140+0 scanout=360x480
```

This is an upright 3:4 image centered on the 4:3 Bubble panel, rather than a
stretched landscape image. The Pyxel validation app reported a 256x240 source
rendered as 512x480 at offset 64,0, preserving its 16:15 aspect.

PicoArch, hardware-rendered RetroArch cores and standalone SDL/GLES routes do
not all expose source-frame geometry. For those routes the harness verifies DRM
ownership and renderer startup, but cannot prove final LCD pixel orientation
without a camera or user observation. They therefore remain physical display
acceptance work under `BUB-P6-10`.

## Pyxel correction

Pyxel now uses an isolated glibc loader, the same captured Bubble
`libmali.so.1` for both EGL and GLES, and the Bubble KMSDRM/ALSA SDL2 build.
The known-good `finardry.pyxapp` stayed alive, owned DRM, reached PCM
`RUNNING`, and passed the 16:15 display contract at volume zero.

The two Pyxel files found on SD2 are not runtime evidence: one fails CRC while
reading `assets.pyxres`, and the other has an invalid zlib stream. This matches
the FAT corruption already detected on that card. They were not modified.
Replacing or repairing those files is media work, separate from the corrected
Pyxel runtime.

## Remaining route-specific findings

- OpenBOR's Debian SDL2 software renderer could not create a matching KMSDRM
  surface. It now uses the already-validated Bubble SDL2 plus Mali GLES2 path.
  The retest owned DRM and held PCM `RUNNING` until bounded termination.
- BlueMSX initializes RetroArch, DRM and ALSA, then terminates with bus error or
  segmentation fault before the first frame for a clean MSX ROM. Disabling
  threaded video did not resolve it. The BlueMSX profile remains visible and is
  marked failed in runtime coverage; the MSX default is changed to fMSX, whose
  272x228 frame produced a centered 573x480 viewport with PCM `RUNNING`.
- Both Sega 32X routes only had a live-media ZIP that the core could not read,
  and no clean 32X sample exists in the supplied Mac ROM set. This is classified
  as unavailable validation content, not an emulator pass or failure.
- No clean monochrome NGP game or Pokemon Mini game exists in the supplied set.
  Those routes remain visible and unverified. NGPC with clean content passed.

## Deployed state

The OpenBOR renderer correction was deployed as source `54a8a2a`. The staged
files matched their host SHA-256 values before switching, then standalone and
all 4,984 app-layer checksums passed on-device. Rollback archive:

```text
/storage/plumos/state/update-rollback/c8a158d-to-54a8a2a-20260903T060500JST.tar
SHA-256 6ba54e1896f5c30bf640c3baf478d91fc36f30353829883c0effcffd5168932d
```

No release was published.
