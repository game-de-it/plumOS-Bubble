# GGFE - the Game Gear frontend

GGFE is a system-specific frontend for plumOS Bubble. It presents a Game Gear
library as a carousel of cartridges drawn with CPU software 3D, and hands a
selected game to the normal plumOS launch path.

It is a separate binary, not a mode inside `plumos-controller-ui`. The stock
frontend keeps every common plumOS menu item untouched, and GGFE can be
tested, replaced or skipped without putting that frontend at risk.

## Why there is no GL

GGFE renders on the CPU into the same RAM shadow buffer the stock frontend
already `memcpy`s into the DRM dumb buffer. It opens no EGL context and never
touches `/dev/mali0`, so it never competes with RetroArch for the GPU or for
DRM master, and the handoff to a game is the release the stock frontend
already performs.

The build gate enforces this: `scripts/build-bubble-frontend.sh` fails if
`plumos-ggfe` links `libEGL`, `libGLESv2`, `libgbm` or `libmali`.

A worst-case frame is roughly 3,500 triangles at 640x480. See
`src/frontend/plumos_cart3d.h` for the renderer and
`src/frontend/plumos_ggfe_model.h` for the shell geometry.

## Reaching GGFE

START > Apps > **Game Gear**.

That entry runs `bin/plumos-ggfe-launch`. The stock frontend shuts its
renderer down before running any `shell:` app, so DRM master is already free
when GGFE starts. On exit the stock frontend reacquires it.

GGFE is a Bubble-only entry and is recorded as such in
`config/frontend/start-menu-coverage.json` under `bubble_only_apps_entries`.

## Controls

There is no on-screen button legend; the controls are documented here instead.

| Button | Action |
|---|---|
| D-pad Left / Up | previous cartridge |
| D-pad Right / Down | next cartridge |
| **A** | launch the selected game |
| **B** | return to the stock frontend |
| **START** | return to the stock frontend |

Notes:

* Physical A is `BTN_EAST` and physical B is `BTN_SOUTH` on this device, per
  `configs/input/bubble-controller-map.json`. GGFE uses those codes, not
  positions.
* Input is ignored while the launch sequence is playing, so a second A press
  cannot start a second game.
* **A does nothing on a cartridge with no runnable core.** Rather than play an
  insert animation that ends in nothing, GGFE logs
  `ggfe_launch=unavailable rom=... reason=...` to `logs/ggfe.log`. See
  *Launch resolution* below for why a core may be unavailable.
* The joypad node comes from `PLUMOS_INPUT_EVENT`, which the launcher fills
  from `plumos-bubble-find-input`. If that is empty GGFE scans
  `/dev/input/event0..15` for a device reporting both `BTN_SOUTH` and
  `BTN_DPAD_LEFT`. The controller map names `event2`, but nothing guarantees
  enumeration order, so the node is never hardcoded.

## Configuration

`config/frontend/ggfe.json`, seeded from
`factory-defaults/frontend/ggfe.json`. Every key has a built-in default, so a
missing or unreadable file still behaves.

### Artwork

```json
"artwork": {
  "prefer": ["title", "boxart"],
  "sources": [
    { "kind": "title",  "root": "sdcard", "path": "Images/gamegear/titles" },
    { "kind": "boxart", "root": "sdcard", "path": "Images/gamegear/boxarts" },
    { "kind": "title",  "root": "sdcard", "path": "thumbnails/Sega - Game Gear/Named_Titles" },
    { "kind": "boxart", "root": "sdcard", "path": "thumbnails/Sega - Game Gear/Named_Boxarts" }
  ],
  "use_plumos_lookup": true,
  "plumos_lookup": [ { "root": "sdcard", "path": "Images/gamegear" } ],
  "classify_by_aspect": true
}
```

`root` is `sdcard` or `plumos`; an absolute `path` ignores it.

### Launch

```json
"launch": {
  "resolver": "bin/plumos-text-ui",
  "system": "gamegear",
  "systems": "config/frontend/systems.json",
  "profile": "",
  "prefer": ["retroarch:genesis_plus_gx", "retroarch:gearsystem",
             "retroarch:picodrive", "picoarch:genesis_plus_gx"],
  "overrides": "state/frontend/ggfe-overrides.json",
  "plumos_overrides": "state/frontend/core-overrides.json",
  "use_plumos_overrides": true
}
```

`profile` is GGFE's system-scope choice and is empty by default.

There is deliberately **no CPU policy setting here**. CPU policy is resolved
by the same chain inside `plumos-text-ui` from `systems.json` and
`core-overrides.json`. A value here would silently override what the user set
in the stock frontend.

## Artwork resolution

Two schemes run side by side. The first hit wins.

**1. GGFE sources.** Each entry in `artwork.sources` declares a `kind`, so a
libretro thumbnail tree can be pointed at directly and GGFE knows what it is
looking at. Ordered by `artwork.prefer`, then by list order.

**2. The stock frontend's scheme**, reproducing `find_thumbnail()` in
`src/frontend/plumos_library_scan.c` so artwork already on the card is picked
up with no extra work:

| step | directory |
|---|---|
| 1 | `<sdcard>/Images/<ROM directory alias>/` |
| 2 | `<sdcard>/Images/gamegear/` |

ROM directory aliases are `GG`, `GameGear`, `MD`, `gamegear`. Within a
directory: extensions `png`, `jpg`, `jpeg`, `webp` in that order; the ROM's
path relative to its system directory (subdirectories preserved) before its
bare basename; and **only the final path component is matched
case-insensitively** - a directory component must match exactly. On the FAT32
SD card that distinction disappears, but on ext4 it does not, and GGFE must
not resolve a file the stock frontend would miss.

`MD` is marked `shared` in `systems.json` because the directory also holds
Mega Drive ROMs, so the scan de-duplicates by stem across aliases.

A stock-scheme hit carries no kind, so it is classified from the decoded
image's aspect: 160:144 is a title screen, anything else is box art. That is
the same test the label uses to decide whether to print the GAME GEAR strip,
so the two cannot drift.

**Only PNG is decoded.** The resolver honours `jpg`, `jpeg` and `webp` so it
stays faithful to the stock frontend's rules, but this build links libpng
alone; such a hit falls back to a plate naming the ROM. Adding libjpeg touches
both the tools image and `frontend/lib` and is tracked separately.

## Launch resolution

GGFE decides **which** profile. `plumos-text-ui` decides **how** to run it:

```
plumos-text-ui launch <system> <relative path> --profile <id> --execute
```

The relative path uses the same scan-cache identity as the stock frontend and
includes the ROM directory alias, for example `gamegear/Sonic.gg`. Artwork
lookup separately uses `Sonic.gg` relative to that alias so existing
`Images/gamegear/` layouts do not gain a duplicated directory component.

That tool builds the command for every runtime, validates the ROM and core
paths, and records recent and resume state. The three runtimes do not agree on
a calling convention - RetroArch takes named flags and an absolute core path,
picoarch and standalone take two positional arguments with the system and CPU
policy passed through the environment - so that knowledge lives in one place.

The chain is **scope first, origin second**:

| # | layer | source |
|---|---|---|
| 1 | ROM, GGFE | `state/frontend/ggfe-overrides.json` |
| 2 | ROM, plumOS | `state/frontend/core-overrides.json` |
| 3 | system, GGFE | `ggfe.json` `launch.profile` |
| 4 | system, plumOS | `core-overrides.json` system scope |
| 5 | catalogue | `systems.json` `default_launch_profile` |
| 6 | preference | `ggfe.json` `launch.prefer` |
| 7 | first available | |

A candidate is taken only if `systems.json` lists it **and** the device has
it. GGFE reorders what plumOS declares; it never invents a profile.

Availability is probed per runtime:

| runtime | requires |
|---|---|
| `retroarch:X` | `cores/X_libretro.so` |
| `picoarch:X` | `cores/X_libretro.so` and `picoarch/bin/picoarch` |
| `standalone:X` | `bin/plumos-standalone-launch` |

Unavailable profiles are kept with a reason rather than dropped, so the
frontend can say why a listed core cannot run.

**GGFE reads `core-overrides.json` but never writes it.** A core picked in the
stock frontend is honoured here, but the two files stay independently owned so
they cannot drift into an inconsistent pair. GGFE writes only
`ggfe-overrides.json`. Both use the same schema; GGFE reads only
`launch_profile` from them.

## Assets

| path | purpose |
|---|---|
| `themes/default/ggfe/logo-strip.png` | red GAME GEAR strip printed on title-aspect labels |
| `themes/default/ggfe/header-logo.png` | wordmark at the top left of the header |
| `fonts/default.otf`, `fonts/cjk-fallback.ttc` | shared with the stock frontend |

Both PNGs are stored at 2x their rendered size. If `logo-strip.png` is
missing, a sheared bold face stands in; if `header-logo.png` is missing, the
header falls back to accent-coloured text.

## Porting to another system or device

The shell dimensions, bracket geometry, label aperture, case size, console
layout and colours are all constants in `plumos_ggfe_model.h` and
`plumos_ggfe.c`. Porting is data, not code:

1. Replace the millimetre constants with the target cartridge's measurements.
2. Size the label aperture from the target's native resolution. The Game Gear
   aperture is exactly 160:144 at 320x288 texels - a 2x integer upscale - so a
   title capture fills it with no letterbox and no resampling blur.
3. Point `artwork.sources` at that system's thumbnail directories and set
   `rom_dirs` to its `directory_aliases` from `systems.json`.
4. Set `launch.system` and `launch.prefer`. Everything else in the launch
   chain follows `systems.json` automatically.
5. Supply the two theme PNGs.

Two constraints the geometry must respect, both learned the hard way:

* The moulding around a recessed panel must be filled as a **ring**. A solid
  fill sits in front of the recess and the depth test drops it.
* Flat shading alone leaves a shell looking flat head-on, because every step's
  wall projects to zero width in a dead-on view. Depth comes from a darker
  raised area, a lit strip on its top edge, and a stepped contact shadow.

## Host verification

None of these need a device:

| tool | checks |
|---|---|
| `plumos_ggfe.c -DPLUMOS_GGFE_HOST` | renders six keyframes to PNG, prints the scan, the profile catalogue and the resolved launch for every ROM |
| `scripts/ggfe-render-test.c` | four views of the cartridge, for the 3D maths |
| `scripts/ggfe-art-test.c` | which artwork rule matched each ROM |
| `tests/test-bubble-ggfe-launch-resolution.sh` | the launch chain, availability, and that plumOS's file is untouched |

Run the tests in the container, not on macOS. bash 3.2 does not honour `set -e`
for a failing `[[ ]]` compound command, so bare assertions in `tests/` are
silently skipped there and the script still prints `result-ok`. The GGFE test
uses explicit `if`/`fail` blocks and fails correctly on both.

## Logs

`logs/ggfe.log`:

```
ggfe_start=ok roms=<n>
ggfe_launch=start rom=<rel> profile=<id> source=<layer>
ggfe_launch=unavailable rom=<rel> reason=<why>
ggfe_launch=done status=<n>
ggfe_renderer=reacquire-failed error=<msg>
ggfe_exit=ok
```

## Known limits

* No core-picker UI yet. The resolution result and each profile's reason are
  already available; what remains is an overlay that writes the choice to
  `ggfe-overrides.json`.
* JPEG and WebP artwork resolve but do not decode.
* Not yet validated on physical hardware.
