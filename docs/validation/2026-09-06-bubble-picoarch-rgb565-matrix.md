# Bubble PicoArch RGB565 byte-order matrix

## Trigger

After the physical Gearsystem correction, PicoDrive showed the same green/blue
colour inversion from both the normal frontend and GGFE.  Treating each report
as a new launcher exception would leave the other PicoArch routes exposed to
the same failure.

## Bounded device method

The normal frontend was placed behind
`/run/plumos/validation/frontend-hold` before its only renderer was stopped.
No frontend and emulator rendered concurrently.  Persistent volume remained
`12`; validation runtime volume and the managed soft-volume path were set to
`0` before any content was started.

PicoArch was built with an opt-in frame probe.  The probe is dormant unless
both validation environment variables are supplied.  For each route it:

1. runs exactly 90 core frames;
2. dumps the final 640x480 scanout as BMP;
3. exits through PicoArch's normal core unload path.

The same clean ROM was used for every core in a system family.  All 20
frontend-exposed PicoArch core IDs were run once with byte swap disabled and
once with byte swap enabled.  All 40 runs returned `rc=0`, produced a 921654
byte BMP, unloaded their core, and released DRM.  The result index SHA-256 was
`1b4706cbae27e59d3779eb97cf3d31a6808925cc60c79b29974a9c72fa4d734d`.
ROMs, screenshots, save data, and states are not repository inputs.

RetroArch was then run with the same core, ROM, and frame count to provide an
independent libretro pixel-format reference for NES, SNES, GB, GBA, and Game
Gear.  The PCE title was still black at 90 frames, so PCE Fast and SuperGrafx
were repeated at 720 frames and compared with a 720-frame RetroArch reference.

## Result

| PicoArch core | Reported format | Bubble byte order | Evidence family |
|---|---|---|---|
| chimerasnes | RGB565 | native | SNES / RetroArch anchor |
| fceumm | XRGB8888 | native | `SET_PIXEL_FORMAT: 1` |
| gambatte | RGB565 | byte swap | GB / RetroArch anchor |
| gearboy | RGB565 | byte swap | GB / RetroArch anchor |
| gearsystem | RGB565 | byte swap | GG / RetroArch anchor |
| genesis_plus_gx | RGB565 | native | GG / RetroArch anchor |
| gpsp | RGB565 | native | GBA / RetroArch anchor |
| mednafen_pce_fast | RGB565 | native | PCE / 720-frame RetroArch anchor |
| mednafen_supafaust | RGB565 | byte swap | SNES / RetroArch anchor |
| mednafen_supergrafx | RGB565 | byte swap | PCE / 720-frame RetroArch anchor |
| mgba | RGB565 | native | GBA / RetroArch anchor |
| nestopia | XRGB8888 | native | `SET_PIXEL_FORMAT: 1` |
| picodrive | RGB565 | byte swap | GG / RetroArch anchor |
| quicknes | RGB565 | native | NES / RetroArch anchor |
| snes9x | RGB565 | native | SNES / RetroArch anchor |
| snes9x2002 | RGB565 | native | SNES / RetroArch anchor |
| snes9x2005 | RGB565 | native | SNES / RetroArch anchor |
| snes9x2005_plus | RGB565 | native | SNES / RetroArch anchor |
| snes9x2010 | RGB565 | native | SNES / RetroArch anchor |
| vbam | RGB565 | byte swap | GB / RetroArch anchor |

The prior MF-compatible `mednafen_ngp` classification is retained as a
compatibility row, but it is not one of Bubble's 20 frontend PicoArch routes.

The seven frontend routes requiring correction are therefore:
`gambatte`, `gearboy`, `gearsystem`, `mednafen_supafaust`,
`mednafen_supergrafx`, `picodrive`, and `vbam`.

## Regression boundary

The launcher no longer owns a growing shell `case` list.  It reads the managed
`share/picoarch/rgb565-byte-order.tsv` table and records format, byte order,
effective correction, and evidence in the route log.  The component manifest
hashes that table.

`tests/test-bubble-picoarch-rgb565-matrix.sh` compares the table with every
unique `picoarch:` route in `systems.json`.  A missing route, duplicate core,
invalid format/order, or change to the exact seven-core correction set fails
the release catalog verifier.  Current result:

```text
bubble_picoarch_rgb565_matrix=result-ok routes=20 rgb565=18 byteswap=7 xrgb8888=2 compat=1
```

The matrix SHA-256 at device acceptance was
`7eff6805dc10eb9eadc13963e962b95ba69c1aca986f63a297fd6d5a0c9d16f1`.

## Final device deploy and readback

The complete PicoArch component was staged and verified before switching it
into `/storage/plumos`.  Final managed hashes were:

| File | SHA-256 |
|---|---|
| `picoarch/bin/picoarch` | `280e99230a1862fa8e4cfe654d7ceb86353e0c9ad795e3749c06f94169065706` |
| `bin/plumos-picoarch-launch` | `ae2d813ad59cda7aa196ee5adff96d6634ee5d01c541905231fb47a04aaa8434` |
| `share/picoarch/rgb565-byte-order.tsv` | `7eff6805dc10eb9eadc13963e962b95ba69c1aca986f63a297fd6d5a0c9d16f1` |
| `components/picoarch/manifest.json` | `c71c2ad240574971fa3c67b6c9e2f4b410085632f97000047f033aa0cefed961` |
| `components/picoarch/checksums.sha256` | `1509a8bf6698d1aa53f343c58fe1758ff7dda2b18067e17892948c037db5012b` |

The global checksum catalog changed 13 target entries: the twelve PicoArch
component files and its component checksum.  The new table was the only added
global line (`12938 -> 12939`); every unrelated pre-existing line was byte-for-
byte identical.  `manifest.json` remained unchanged at
`b2addd949323c8e05364e8409a44feb98c6e89fad82257e4a9adc7974b88b041`.
The final global checksum catalog was
`18204e826d5290dd50f57573fdc38b8e0dcbc880c7c2b0c5e40ce009ee530264`.

Rollback is stored at
`state/app-deploy/20260906-picoarch-rgb565-final/rollback.tar` with SHA-256
`e87f5c4b3af310a39069c10c46a86aca49d9a4afee2988b80b62bece0221b113`;
`rollback.remove` records that the new table did not exist before this deploy.

With the force-override removed, all 20 cores were run once more through the
final launcher.  Each route logged the expected table decision and its BMP was
byte-identical to the previously accepted native/swap result:

```text
final_default_routes=20 rc_failures=0 screenshot_mismatches=0 log_mismatches=0
```

Validation-only state/save directories were removed.  The hold was removed,
persistent and runtime volume were restored to `12`, all CPU governors were
`ondemand`, and the device returned to exactly one
`plumos-controller-ui-fbdev` process with no PicoArch, RetroArch, or GGFE
process left running.
