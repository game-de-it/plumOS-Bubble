# Bubble emulator / frontend coverage plan

Date: 2026-09-02

## Decision

The QuickNES path proved the Bubble DRM, evdev, ALSA, foreground ownership,
and return-to-frontend lifecycle. It is not a release-shaped emulator set.
Further content testing is paused until Bubble has a complete common plumOS
runtime catalog and every catalog route is either executable or visibly marked
with a tracked device-specific reason.

This prevents a development-only single-core package from being mistaken for
a release payload. A release candidate must fail closed if it contains only the
QuickNES baseline or if a packaged core has no frontend route.

## Read-only ROM inventory boundary

The supplied source is `/Volumes/public/02/motoki/emu/ROM/rom2`. Inventory was
limited to directory names, extensions, and counts. No ROM, BIOS, save, state,
credential, or configuration file was copied, modified, hashed into Git, or
added to a build artifact.

Observed top-level directory count: 33.

### Direct common-catalog directories

The following 27 directories directly match a common system id or alias:

`dreamcast`, `fbneo`, `gamegear`, `gb`, `gba`, `gbc`, `mame`,
`mastersystem`, `megadrive`, `n64`, `nds`, `nes`, `ngpc`, `openbor`, `pc`,
`pc88`, `pcengine`, `pcenginecd`, `pico-8`, `ports`, `psp`, `psx`, `pyxel`,
`saturn`, `scummvm`, `snes`, and `wonderswan`.

`mame` resolves to the common `mame2003plus` route, `pc` to `dos`, `pico-8`
to `pico8`, and `snes` to `sfc`.

### Directories requiring an explicit policy

| Source directory | Policy |
|---|---|
| `ATARI` | Scan its system subdirectories through nested aliases: 2600, 5200, 7800, 800, Jaguar, Lynx, and arcade groups. |
| `_etc` | Treat as a container of additional common systems. Add explicit nested aliases; never scan the whole tree as one system. |
| `msx2` | Map to the common `msx` system while preserving the source directory. |
| `bios` | BIOS source only. Mount/read as user media; never list as games or include in managed checksums. |
| `3ds` | No common plumOS/RK3566 runtime exists. Keep a visible `unsupported` system state; do not silently hide it or claim Citra support. |
| `01` | Foreign handheld/application management tree, including saves and configuration. Exclude from game scanning and never mutate it. |

The typoed `_etc/viretualboy` directory must be handled as an explicit alias
for `virtualboy`; the source directory must not be renamed.

## Common plumOS catalog baseline

Reference: `plumOS-MF` v1.0.4, source commit `0095017`.

| Item | Baseline |
|---|---:|
| Systems | 97 |
| Total launch-profile occurrences | 196 |
| RetroArch route occurrences | 153 |
| Unique RetroArch core ids | 116 |
| PicoArch route occurrences | 36 |
| Unique PicoArch core ids | 20 |
| Standalone routes | 5 |
| Pyxel routes | 1 |
| External Ports routes | 1 |
| Source core records | 114 |
| Packaged libretro binaries including aliases | 118 |

The five standalone routes are PCSX-ReARMed, PPSSPP, DraStic, OpenBOR, and
YabaSanshiro. The common Apps menu also contains Scraping, File Manager, Music
Player, RetroArch, Pyxel Setup, PortMaster, and PortMaster Update. Bubble must
retain those entries, showing an implementation state when a component is not
yet runnable.

## Bubble runtime classes

### Software RetroArch cores

108 source-core records use software rendering. These are the first bulk port
target because the Bubble plain-DRM RetroArch path has already been physically
accepted. Each core still requires an AArch64 load test, BIOS/content policy,
and at least one representative lifecycle test for its runtime family.

### GLES RetroArch cores

Six core records require GLES: Flycast, Flycast Xtreme, SwanStation Xtreme,
Mupen64Plus-Next, ParaLLEl N64, and YabaSanshiro. They may be packaged only in
a GPU-scoped component. All six now pass AArch64 host load-smoke with the
hash-pinned Bubble stock Mali capture, but that capture is explicitly limited
to local-device validation. Vendor Mali provenance/license, redistribution,
physical rendering, and kernel-DDK compatibility remain gates; a future open
GPU route may replace that dependency.

### PicoArch

The common catalog exposes 36 PicoArch routes over 20 core ids. The MF binary
is not copied as a Bubble runtime: its input and fbdev behavior is device
specific. Bubble needs its own build, input mapping, DRM/fbdev ownership,
audio recovery, menu/exit policy, and component-scoped libraries.

### Standalone, Pyxel, and Ports

All five standalone routes need Bubble-specific display, input, audio, and
session wrappers. PCSX-ReARMed, YabaSanshiro, PPSSPP, and OpenBOR now have
host-built Bubble components. DraStic retains a visible route but is rejected
with an explicit unsupported message because Bubble lacks the `/dev/miyooio`
input bridge expected by the verified prebuilt integration; its closed-binary
redistribution decision is also unresolved. Pyxel and PortMaster have
checksum-verified host components, with PortMaster using a compatibility
profile that remains pending per-port physical validation.

## Storage gate

The live probe has a 64 GB OS SD but p3 is still the diagnostic 1.5 GiB
partition, with about 1.3 GiB free. The MF complete runtime reference occupies
about 1.5 GiB before Bubble-specific growth. Therefore the full catalog must
not be copied into the current p3 layout.

Before bulk runtime deployment:

1. Host-test the V90S-derived first-boot state machine with interruption and
   rerun fixtures.
2. Expand p3 to the selected managed-runtime size and create p4 from remaining
   space without touching an existing unknown p4 or SD2.
3. Keep p1/p2 immutable and verify their hashes after provisioning.
4. Resolve OS SD and SD2 by identity rather than `mmcblk` number.
5. Preserve ROM, BIOS, saves, states, frontend settings, RetroArch settings,
   Wi-Fi credentials, and PortMaster-managed data.

## Required machine gates

The coverage verifier must enforce both directions:

1. Every packaged core binary is referenced by a frontend route or by a
   visible machine-readable unsupported record.
2. Every frontend launch profile resolves to an installed launcher and core,
   or to a visible unsupported record with a TODO id.
3. Every system has extensions, source directory aliases, default profile,
   BIOS/content policy, renderer class, and save/state ownership.
4. Every component has pinned source, license evidence, architecture and ELF
   dependency checks, manifest, and checksums.
5. Managed app-layer checksums exclude all user media and mutable settings.
6. A release candidate fails if it contains the bring-up marker
   `core_baseline: [quicknes]`, declares incomplete coverage, contains ROM/BIOS
   content, or retains development credentials.

## Acceptance order after the catalog is complete

1. Host: parse all configuration and prove all 196 route occurrences.
2. Host/AArch64: load-smoke every libretro core and verify runtime libraries.
3. Host: exercise every FE route selection, including unsupported-state text.
4. Device: verify FE listing and core selection before launching content.
5. Device: run one representative item per runtime family, then every distinct
   launcher/core route that can execute on Bubble.
6. Device: check video, all controls, menu/exit, audio, save/state, FE return,
   and process/device-owner cleanup.
7. Device: verify power, filesystem cleanliness, reboot persistence, and
   update/rollback separately.

No release or publication is authorized by these gates. Publication remains a
separate action after explicit user approval.
