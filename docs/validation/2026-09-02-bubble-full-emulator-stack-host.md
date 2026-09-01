# Bubble full emulator stack host validation

Date: 2026-09-02

## Scope and media boundary

This gate was completed before another SD write or device deployment. The ROM
source `/Volumes/public/02/motoki/emu/ROM/rom2` was used only for the prior
read-only directory/extension inventory. No ROM, BIOS, save, state, credential,
or mutable configuration file was copied into the repository or app layer.

## Frontend coverage

The Bubble frontend contains 98 visible systems: the 97-system plumOS-MF
common baseline plus a visible unsupported 3DS entry. The catalog contains 196
launch-profile occurrences and resolves these unique runtime identifiers:

- RetroArch: 116 core ids
- PicoArch: 20 core ids
- standalone: 5 ids
- Pyxel: 1 route
- external Ports: 1 route

Nested aliases cover the observed `ATARI`, `_etc`, typoed
`_etc/viretualboy`, and `msx2` source directories without renaming or changing
the supplied media. Scraping, File Manager, Music Player, RetroArch, Pyxel
Setup, PortMaster, and PortMaster Update remain visible. Incomplete apps use
explicit placeholder launchers rather than disappearing from the FE.

Command:

```sh
PLUMOS_BUBBLE_APP_ROOT="$PWD/output/app-layer/bubble/plumos" \
  ./scripts/verify-bubble-emulator-catalog.sh
```

Result:

```text
bubble_emulator_catalog=result-ok systems=98 profiles=196 retroarch_ids=116 picoarch_ids=20 standalone_ids=5 release_complete=no
```

## Runtime components

The assembled app layer contains seven managed components: frontend,
RetroArch, libretro cores, PicoArch, standalone emulators, Pyxel, and
PortMaster. All component checksum manifests and the aggregate app-layer
checksum passed.

All 114 pinned libretro source records built as AArch64 objects. A new gate
then loaded every primary core with `RTLD_NOW`, verified the mandatory libretro
entry points, and called `retro_api_version`. The first pass exposed two real
packaging defects that file-existence checks had missed:

- Flycast Xtreme did not retain its OpenMP link dependency because the recipe
  overrode `LDFLAGS`; its rebuilt ELF now declares `libgomp.so.1`, and the
  dependency is copied into the managed app-layer instead of relying on the
  host container or the stock root filesystem.
- MBA Mini omitted the synchronous OSD work queue and `vbiparse` object used by
  its CHD/laserdisc code; both are now pinned patches derived from the same
  MAME 2010 libretro implementation boundary.

Final result:

```text
bubble_libretro_load_smoke=result-ok pass=114 fail=0
```

PicoArch, PCSX-ReARMed, YabaSanshiro, PPSSPP, OpenBOR, Pyxel, and PortMaster
have checksum-verified Bubble packages and FE launchers. DraStic remains
visible unsupported: its available closed ARMHF integration expects
`/dev/miyooio`, which the Bubble does not expose. It is also not release
eligible until redistribution is resolved.

The six GLES libretro cores and GLES standalone paths use the hash-pinned Mali
libraries captured read-only from the Bubble stock OS. Those files are marked
`local-device-validation-only`; this app layer is not a redistributable release.

## Aggregate result and remaining gate

The assembled managed payload is approximately 1.8 GiB. Its manifest declares
`core_baseline=all-114-source-records`, `catalog_complete=true`,
`release_complete=false`, and `publishable=false`. It contains no user-supplied
ROM, BIOS, save, or test content. Managed runtime assets do include the
redistributable blueMSX C-BIOS and the non-release-eligible DraStic packaged
BIOS, which are identified separately in the aggregate manifest.

The current device p3 is the 1.5 GiB diagnostic partition, so this payload must
not be live-deployed there. The next device cycle must first integrate and
host-test V90S-derived first-boot expansion and p4 creation, then perform one
batched physical pass covering FE enumeration, representative content,
video/input/audio, menu/exit, save/state, FE return, and device-owner cleanup.
