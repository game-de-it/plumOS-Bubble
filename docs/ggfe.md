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
| D-pad Left | previous cartridge; hold to repeat |
| D-pad Right | next cartridge; hold to repeat |
| D-pad Up | five cartridges back |
| D-pad Down | five cartridges forward |
| **A** | launch the selected game |
| **X** | toggle cartridge cases while browsing |
| **B** | return to the stock frontend |
| **START** | return to the stock frontend |

Notes:

* Physical A is `BTN_EAST` and physical B is `BTN_SOUTH` on this device, per
  `configs/input/bubble-controller-map.json`. GGFE uses those codes, not
  positions.
* Physical X is `BTN_NORTH`. GGFE persists the case setting in its own state
  file, and the launch animation respects the remembered ON/OFF choice.
* Left/right wraps between the final and first cartridge in either direction.
  GGFE supplies the same 350 ms initial delay and 95 ms repeat interval as the
  plumOS frontend even when the input bridge emits no kernel repeat events.
  Up/down is a single cyclic five-cartridge jump and does not repeat.
* Artwork for the visible destination range is decoded before a transition
  starts, so first-use PNG work cannot skip the motion. `logs/ggfe.log` reports
  measured FPS, maximum frame time and slow frame count once per second.
* B/START returns to the stock frontend when GGFE was opened from Apps. During
  the standalone validation procedure, `frontend-hold` deliberately prevents
  that frontend from restarting, so B/START leaves a black screen until the
  marker is removed. That black screen is an exited GGFE, not a game launch.
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

## Carousel motion

Two motions are selectable from `ggfe.json`:

```json
"motion": { "model": "snap", "scroll_ms": 240 }
```

| model | curve | input |
|---|---|---|
| `snap` (default) | ease-out with a settle overshoot, 240 ms | re-aims from wherever the carousel is; GGFE supplies held-key repeat |
| `gallery` | symmetric smoothstep, 360 ms | always completes, one further press queued behind it |

`snap` is GGFE's own motion; `gallery` matches the plumOS gallery and was
adopted while chasing the frame rate.

**The choice is presentation only.** Compose cost is set by how many
cartridges fall inside the carousel span, and does not change with the easing
curve or with whether the carousel is moving. Measured on the build machine
across a six-ROM library:

| carousel position | ms/frame |
|---|---:|
| 0.0, at the end of the library | 1.03 |
| 1.0 | 1.36 |
| 2.0, resting mid-library | 1.51 |
| 2.5, mid-scroll | 1.42 |
| 5.0, at the other end | 1.03 |

Mid-scroll is slightly *cheaper* than resting on a slot. What the device
measurements recorded as "static at the left edge is 60 fps, scrolling in the
middle is 30" is the difference between four cartridges on screen and seven,
not between still and moving. The motion model changes how long the carousel
spends in the busier state, not what a frame there costs.

## Remembered view options

`state/frontend/ggfe-state.json` holds GGFE's own view state - currently just
whether the cases are shown. It is written when the toggle is pressed, through
a temporary and a rename so a power cut leaves the previous file rather than a
truncated one. The temporary file is flushed and synced before the rename, the
directory entry is synced afterwards, and write/sync failures are logged rather
than installing incomplete state.

It is deliberately separate from the launch overrides and from anything the
stock frontend owns, so the three cannot corrupt one another.

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
ggfe_renderer=ready backend=<drm|fbdev> xres=<w> yres=<h> bpp=<n> shadow=<0|1> double_buffer=<0|1>
ggfe_frames=fps=<n> frames=<n> elapsed_ms=<n> max_frame_ms=<n> slow_frames=<n> compose_us=<avg>/<max> blit_us=<avg>/<max> present_us=<avg>/<max>
ggfe_launch=start rom=<rel> profile=<id> source=<layer>
ggfe_launch=unavailable rom=<rel> reason=<why>
ggfe_launch=done status=<n>
ggfe_renderer=reacquire-failed error=<msg>
ggfe_exit=ok
```

The three timing pairs are average/maximum microseconds for software scene
composition, RGB-to-panel conversion, and DRM/fbdev presentation.  They make a
low frame rate attributable without guessing from the CPU governor alone.

## Rasteriser performance

The frame is dominated by the software rasteriser; on a scrolling carousel
everything else together is under 5% of compose time. Two properties of the
meshes drive the cost.

**Fans produce slivers.** Every rounded outline is filled as a triangle fan
from its centroid, so a shell face is 28 long thin diagonal triangles. A
sliver's bounding box is enormous next to its area, and walking that box was
costing eight pixels tested for every one shaded - 3.0 M tested against 357 k
shaded per frame. `cart3d_raster` therefore solves each edge for the x range
it allows on the current scanline and iterates only that span, which brings
tested fragments to 563 k without changing what is drawn.

**Most triangles are flat colour.** 1/w, u/w and v/w are linear in screen
space, so they are stepped per pixel rather than rebuilt from barycentrics
each time, removing six multiplies per fragment that flat triangles never
needed.

**One core was doing all of it.** The device has four. The frame is split into
24 horizontal stripes which worker threads claim on demand; a thread owns
whole scanlines of both the colour and depth buffers, so no two threads touch
the same pixel and there is nothing to lock. Fixed bands per worker were tried
first and scaled badly - the cartridges sit in the middle of the screen, so the
top and bottom quarters had almost nothing to do and four cores behaved like
two. Claiming narrow stripes balances whatever the scene looks like.

Edge functions are evaluated from their equation on every scanline rather than
carried down by addition. Six flops a row is nothing next to the pixels, and it
makes a row depend only on its own coordinates, so **output is bit-identical
whatever the stripe layout or thread count** - verified by comparing one-thread
and four-thread renders.

Measured on the build machine, a 300-frame scroll:

| | ms/frame |
|---|---:|
| before | 5.57 |
| span bounds | 3.48 |
| stepped interpolation | 3.20 |
| 2 threads | 2.12 |
| 4 threads | **1.35** |

Shaded overdraw is 1.2x screen area, close to the floor for this scene, so
further gains have to come from drawing less rather than from the inner loop:
the closed cases contribute about 43% of compose for a frosted overlay, and
their hidden faces - the tray back plate behind the cartridge, the lid back
face - are the candidates.

**Clearing and the panel conversion were still single-threaded.** Both are as
parallel as the rasterising, and the panel conversion alone was measured at
2.2 ms on the device - an eighth of the whole frame budget spent moving bytes.
They now run through the same stripe pool, which also gives the depth clear
better locality: a worker clears the stripe it is about to draw into.

**HUD glyphs are cached.** The header and title are the same handful of
characters every frame, and rasterising them again each time was 13% of
compose for pixels identical to the previous frame's. A 192-entry cache keyed
on codepoint and size halves the HUD stage, bit for bit.

GGFE also raises the CPU governor for its own lifetime and restores it on
every exit path, the same shape the RetroArch and Pyxel launchers use. It is
one of the few plumOS routes that is genuinely CPU bound, and ondemand was
measured on this device reaching full clock in only a third of samples.

Span bounds are computed with one multiply where the original loop accumulated
additions, so a handful of edge pixels round differently against the pre-span
build: 0.13% of pixels by at most 18 levels, invisible at 24x amplification.

Also rejected after measuring: level of detail on distant cartridges. Dropping
the contact shadow and the SEGA emboss from *every* cartridge - far more than
an LOD scheme would - was worth 3%. Fill is dominated by simply covering the
cartridges and their cases, not by detail geometry, so there is nothing left
to win by simplifying the mesh.

Also rejected after measuring: merging the tray and lid into one layer while
the case is shut. The two do cover the same area and compositing their alphas
is arithmetically right, but they carry different surface normals and the
tray's rim and back plate supply the case's edge definition - the merged
version reads flat and washed out. It was worth 20% and was not taken.

Rejected after measuring: baking the label sheen into its texture removed an
expf per fragment but was only 5% and shifted the label's appearance, because
clamping then moved ahead of the shade multiply. The expf now early-outs
instead, which is free and changes nothing.

Measure on the device with `ggfe_frames=` in `logs/ggfe.log`, which reports
compose, blit and present separately. `-DGGFE_PROFILE` additionally breaks
compose into stages and adds a 300-frame scroll benchmark to the host build.

## Known limits

* No core-picker UI yet. The resolution result and each profile's reason are
  already available; what remains is an overlay that writes the choice to
  `ggfe-overrides.json`.
* JPEG and WebP artwork resolve but do not decode.
* Not yet validated on physical hardware.
