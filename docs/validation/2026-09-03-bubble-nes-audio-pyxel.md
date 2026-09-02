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

## Remaining device acceptance

Deployment must preserve the active RetroArch config and all ROM, BIOS, save,
state and frontend data. After relaunching the same FCEUmm content, acceptance
requires sustained ALSA `RUNNING` without a return to `PREPARED`, no audible
skip at normal `ondemand`, correct picture/aspect/input, and normal FE return.
Pyxel requires an FE launch of actual `.pyxapp` content, visible picture,
input, audio where applicable and normal FE return. Neither item is closed by
the host import test alone.
