# Bubble PortMaster runtime and device startup validation

Date: 2026-09-06

## Scope

This validation addressed the PortMaster GUI startup failure on the GKD Bubble
and reviewed the PortMaster fixes from the MF, V90S and Pixel2 repositories.
The mutable PortMaster payload, ROMs, saves and configuration were not replaced.

The device package is the pinned official PortMaster release
`2026.06.23-0015`, SHA-256
`772f2d56fc1abfbf79a3404ca78f240776c81c5a5b92786a0a748ae554339b7b`.

## Failures found on Bubble

The startup failure was not one fault:

1. importing the GUI SDL modules failed because the stock Bubble root did not
   provide the transitive `libgthread-2.0.so.0`, GLib, PCRE2 and legacy
   `librt.so.1` dependencies;
2. the stock root did not provide `pgrep` or a port-compatible Bash runtime;
3. direct validation referred to a nonexistent frontend-stop helper, leaving
   the frontend as the DRM owner;
4. after ownership was fixed, PySDL2 selected utility-app Mesa GBM even though
   the Mali EGL/GLES DSO was requested, and window creation failed with
   `EGL not initialized`;
5. repeated validation had already exhausted PID 1's bounded frontend restart
   budget, so releasing a validation hold did not by itself restore the FE.
6. installed ports run under the component Bash, while the stock root exposed
   only a small subset of BusyBox applets as external commands. Apotris first
   failed on `basename`, `tar`, `rm`, `cp` and `tee`;
7. after exposing the applets, Apotris and GPTokeYB could not load the stock
   glibc/C++ and SDL dependency closure because the per-port launcher replaced
   the trusted library path with only the adapter directory; and
8. third-party scripts are allowed to replace `LD_LIBRARY_PATH` and
   `LD_PRELOAD`, so a correct initial environment alone did not protect child
   processes or provide reliable session cleanup.

The final GPU fix is deliberately not a software fallback. Bubble's stock GPU
runtime is one stateful mega-DSO, so the GUI preloads canonical
`emulator/lib/libmali.so.1` and puts `emulator/lib` first in the explicit Python
loader path. SDL KMSDRM therefore resolves EGL, GLES and GBM from the same
vendor implementation.

## Cross-series history review

The Bubble adapter now carries the applicable lessons from the other plumOS
ports:

| Prior implementation | Bubble treatment |
| --- | --- |
| MF GUI restart marker | stale marker consumption, bounded restart loop and requested-restart logging |
| MF GUI audio and native font/cairo closure | component-owned SDL mixer, OpenAL, codecs, GLib, FreeType, HarfBuzz, Cairo and Pixman closure |
| MF isolated runtime libraries and FAT bind cleanup | runtime-only library directory plus ownership-checked normal/lazy unmount recovery |
| MF EGL selection | canonical Bubble Mali EGL/GLES/GBM selection, with software fallback forbidden |
| MF patcher runtime | component-owned Bash, `libtinfo`, patcher override and LOVE executable normalization |
| V90S architecture boundary | AArch64 is supported; ARMHF is explicitly rejected because Bubble has no general ARMHF loader contract |
| Pixel2 missing `pgrep` | read-only `/proc` implementation for the upstream `pgrep -f` use |
| Pixel2 GPTokeYB exit recovery | caller- and PID-owned stop path; broad unowned `pkill` is rejected |
| Pixel2 session/mount recovery | one session process group plus inherited session identity, owned PID validation, pre-launch stale cleanup and post-exit cleanup |
| Pixel2 exec environment guard | `execve`, `execveat`, `posix_spawn` and `posix_spawnp` interposition keeps Bubble's trusted DSO path and session identity even when a port replaces its environment |
| Pixel2 update hardening | pinned download metadata, staged validation, atomic replacement and executable normalization |

The Pixel2 synchronous installed-port audit was not copied into GUI startup.
Its history showed that doing a full mutable-port walk on every launch can take
minutes and can strand mounts after interruption. A static per-port audit must
remain an explicit diagnostic/update operation, not a GUI launch gate.

## Host gates

`tests/test-portmaster-bubble-runtime.sh` covers:

- GUI `ctypes` preflight and transitive DSO closure;
- canonical Mali preload and vendor-GBM-first loader order;
- `pgrep -f`, denied unowned `pkill`, managed Bash and patcher bridge;
- LOVE executable normalization;
- frontend hold ownership, foreign-hold rejection and managed FE restoration;
- stale/requested GUI restart markers; and
- normal then lazy recovery of only tracked PortMaster mounts.

Additional focused tests cover:

- the Linux execution guard, including a child that replaces its library,
  preload and session variables;
- cleanup of only processes carrying the owned PortMaster session ID; and
- `.tar.xz` extraction through BusyBox `unxz`, while all other tar operations
  remain delegated to the stock applet.

The reproducible component build passed all 244 SHA-256 entries with adapter
28 at source commit `0a93de6`. Mutable `apps/portmaster/installed.json` remains
a first-install seed but is deliberately excluded from component checksums.

## Device evidence

Adapter 28 was staged, archive-hash verified, extracted, component-hash
verified and switched file by file with rollback before the final readback.

- manifest: `adapter_version=28`, `source_ref=0a93de6`;
- mutable `installed.json` SHA-256 before and after:
  `dda981ad47dc16b78e21c3fedc1fd118fe4ee8e5c122a603274bf72fdf4d506f`;
- GUI remained alive beyond 22 seconds;
- process mappings contained only
  `/storage/plumos/emulator/lib/libmali.so.1` and
  `/storage/plumos/emulator/lib/libgbm.so.1` for the GPU path;
- no Mesa DRI, `swrast`, `zink`, utility-app GBM or `EGL not initialized`
  appeared in the final launch range;
- the frontend was absent while the GUI owned DRM; and
- all temporary incoming deployment directories were removed after readback;
- a fresh `.tar.xz` fixture was extracted successfully by the new shim on the
  device (`xz_tar=device-ok`), then its exact temporary files were removed;
- Apotris, GPTokeYB and the port's `tee` helper were simultaneously alive and
  carried one `bubble-*` session ID, while the FE was stopped;
- the final Apotris launch range had none of the earlier `command not found`,
  `invalid tar magic`, `libstdc++.so.6` or `libpthread.so.0` failures; and
- the owned stop path removed all tagged descendants and temporary mounts,
  cleared the validation hold and restored exactly one FE process (PID 8187).

The latest log still contains `ERROR: Could not restore CRTC` and
`Failed to open PWM`. Neither prevented Apotris/GPTokeYB from remaining alive
or the owned stop/FE-return sequence from completing. They are retained as
follow-up evidence rather than suppressed or treated as successful hardware
acceptance.

Apotris is the only installed port script on this device, so it is the current
representative AArch64 runtime. Process/loader/lifecycle acceptance is complete.
Physical LCD, controller and audio behavior through the normal FE selection is
still a user-observed acceptance step; process liveness alone is not recorded
as visual or input acceptance.

## Capacity note

Existing exact PortMaster rollback directories, including adapter 26 to 27 and
27 to 28, were retained because deleting rollback data was not part of this
validation. The device had about 107 MiB free before the final delta. Old
intermediate rollback directories may be removed only with an explicit target
boundary while retaining the latest known-good rollback.
