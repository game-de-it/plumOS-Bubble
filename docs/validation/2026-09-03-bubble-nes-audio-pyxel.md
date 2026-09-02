# Bubble NES audio and Pyxel runtime correction (2026-09-03)

## Physical reports and pre-change evidence

The user reported audible skipping while playing
`ダウンタウン熱血物語.nes` through RetroArch FCEUmm. The same physical session
reported correct orientation, aspect ratio and game audio route before the
skipping was investigated. Pyxel content failed to start independently.

The NES process used about 11-15 percent CPU while the system remained about
82-87 percent idle. ALSA exposed a 48 kHz stereo S16_LE stream with a 768-frame
period and 3072-frame buffer. Repeated `/proc/asound` samples showed the PCM
returning to `PREPARED` and `avail_max` exceeding the buffer size. This is a
real playback underrun; it is not evidence that RK3566 lacks NES capacity.

Bubble patch `013-bubble-drm-page-flip-pacing.patch` intentionally waits for
each atomic DRM page-flip event before reusing a buffer. The active RetroArch
configuration had `video_threaded = "false"`, so that display wait occurred on
the same producer path that feeds audio. A temporary `performance` governor
probe suppressed the symptom, but it is not used as the correction. All CPU
governors were restored to `ondemand` immediately after that diagnostic.

Pyxel's runtime log failed before game code with:

```text
ImportError: libdl.so.2: cannot open shared object file: No such file or directory
```

`readelf` confirms that `pyxel_binding.abi3.so` declares `libdl.so.2` as a
NEEDED object. The Bubble System is intentionally minimal and does not provide
that compatibility DSO.

## Implemented host correction

RetroArch now uses the V90S-derived full factory configuration already proven
by the Pixel2 port. The Bubble adaptation has 3376 unique keys and keeps only
the required device differences: `/storage` paths, unrotated DRM scanout,
RK817 ALSA at 48 kHz/64 ms, and the physically recorded Bubble input mapping.
The config merger atomically installs a new config, replaces only an exact
legacy factory, or appends missing keys without overwriting user values.

The game launcher applies launch-scoped display contracts on every route:

- software cores: `video_driver=drm`, empty context, `video_threaded=true`
- hardware cores: `video_driver=gl`, `video_context_driver=kms`,
  `video_threaded=true`

This moves the blocking page-flip wait away from the emulation/audio producer
without raising CPU clocks or changing emulator accuracy. It also prevents a
driver saved by one renderer class from leaking into the next route.

The Pyxel component now ships its own AArch64 `libdl.so.2`, following the same
component-scoped ABI boundary already used by RetroArch. The Bubble tool image
also includes `python3-pip` and `file`: the builder requires pip, and uses
`file` to discover every ELF extension before recursively collecting Python
standard-library dependencies.

## Host verification

```text
bubble_retroarch_config_test=result-ok keys=3376 duplicates=0
bubble_retroarch_launcher_test=result-ok
bubble_pyxel_runtime=result-ok libdl=component-scoped
pyxel_import=result-ok version=2.9.3
Library soname: [libdl.so.2]
```

## Device acceptance gates

Deployment must preserve the active RetroArch config and all ROM, BIOS, save,
state and frontend data. The same FCEUmm content must sustain ALSA `RUNNING`
without a return to `PREPARED` and have no audible skip at normal `ondemand`.
Picture, aspect, input and normal FE return remain separate route gates. Pyxel
requires an FE launch of actual `.pyxapp` content, visible picture, input,
audio where applicable and normal FE return. Pyxel is not closed by the host
import test alone.

## Managed live deployment

The managed delta was deployed without stopping the already-running FCEUmm
session. Device-side staging hashes passed before atomic rename. The rollback
archive is
`state/update-rollback/4039c74-20260902T152139Z-pre.tar` with SHA-256
`2b258ed3f2468b2564f573ba2837bb5653721241036d6cbdfa20c370cc401ec6`.
It contains the 12 pre-existing changed files; `apps/pyxel/lib/libdl.so.2` and
`bin/plumos-retroarch-config-merge` were absent despite entries in the old
managed metadata, so there was no old payload to archive for those two paths.

Post-switch verification passed:

```text
source_ref=4039c74
frontend checksums=141/141
retroarch checksums=109/109
pyxel checksums=2210/2210
app-layer checksums=4977/4977
device_pyxel_import=result-ok version=2.9.3
governors=ondemand
```

The active RetroArch, frontend and system setting hashes remained respectively
`13399c597e7ef33dc33e7bfa158d9c6810b85b79c1a8575aeb7a86445d288628`,
`1fece30c9240a260ed5c480c5da9873f9af3052b7ba796a129ffa065c7d64ee4`,
and `a623fcc8319e92114ba0c4fe6710961d07324f3a45d579ba4da703741f3ac063`.
The running game retained its original PID and therefore still used the old
non-threaded launch. NES audio acceptance begins only after the user exits and
relaunches that content.

## Post-relaunch NES audio acceptance

After a device reboot and FCEUmm relaunch, the launch-scoped config was active:

```text
retroarch_pid=1634
video_driver=drm
video_context_driver=
video_threaded=true
audio=S16_LE stereo 48000 Hz, period=768, buffer=3072
governor=ondemand
```

The user physically confirmed that the audible skipping had disappeared.
Two consecutive status windows sampled the same ALSA owner 95 times over 95
seconds; all 95 samples were `RUNNING`, none was `PREPARED`, and `hw_ptr`
advanced monotonically. At the final read the uninterrupted stream had passed
five minutes:

```text
owner_pid=1634
samples=95 running=95 prepared=0 other=0
hw_ptr=15623984
stream_duration=325.5 seconds at 48000 Hz
largest observed avail_max=2267 < buffer_size=3072
governor=ondemand
```

This closes the FCEUmm NES speaker-audio regression without a performance
governor override. It does not generalize the result to N64, headphones or any
other core/route; those remain open under `BUB-P4-A02` and `BUB-P6-10`. Pyxel
physical FE launch and return also remain open.

## RetroArch configuration and RGUI resume correction

The user subsequently reported that the plumOS hotkeys and RGUI theme were not
active, and that returning to content after opening RGUI hung. Device readback
showed why the configuration looked only partially ported. The active file was
created by the first full-config migration, which appended missing keys but
correctly preserved all existing values. Those existing values were the 123
defaults serialized from the earlier 58-key Bubble configuration, including
`rgui_menu_color_theme = "4"`; preserving them therefore also preserved the
wrong baseline.

The merger now performs a bounded three-way migration for that exact factory
generation. It replaces a value only when the active line still exactly equals
the captured pre-port default and the new V90S-derived factory has a different
value. Explicit user changes continue to win. Before switching the active file,
it stores the original at `state/retroarch/pre-v90s-active.cfg`. The factory
mapping was also corrected to the measured Bubble layout: D-pad buttons 13-16,
L3/R3 buttons 11/12, right-stick axes 2/3, Function2 menu and Function1
screenshot. Conflicting L2 hold-fast-forward and R2 rewind bindings were
removed.

The RGUI hang was independent of the cfg migration. The plain DRM driver set up
a new menu surface on the page that the producer was also about to reuse. A
commit of an already-scanned framebuffer may not generate the expected page
flip event, leaving the resume path waiting indefinitely. Patch 014 records the
surface role, gives RGUI three pages, advances the producer away from initial
scanout, and keeps the RGUI commit synchronous while game frames retain the
threaded non-blocking submission path.

Host verification passed the 3376-key migration fixture, clean patch
application, AArch64 RetroArch build, 114/114 core catalog, and complete
app-layer assembly. Managed deployment source `4419415` then passed device-side
verification: frontend 141/141, RetroArch 110/110, libretro core component
1425/1425, and app layer 4978/4978. The previous managed files are retained in
`state/update-rollback/4039c74-to-4419415-ra-menu.tar` with SHA-256
`fec77b152c057a61245ce8547ef3de57162306af82376eaff3c1166428c98372`.

The active cfg migration reported `result-migrated-pre-v90s added=123`; its
pre-migration SHA-256 is preserved by the backup as
`f3ffcb254b82028deed04217bccde5150e57c61dad7ce22e0ef91a113bb36407`.
Frontend and system configuration hashes remained unchanged. Physical
acceptance still requires launching content with the new binary, opening RGUI
with Function2, resuming repeatedly without a hang, checking the theme and
Function1 screenshot, and returning normally to the frontend.
