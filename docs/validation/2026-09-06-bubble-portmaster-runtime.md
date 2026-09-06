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
| Pixel2 session/mount recovery | one session process group, owned PID validation, pre-launch stale cleanup and post-exit cleanup |
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

The reproducible component build passed all 241 SHA-256 entries with adapter
24 at source commit `8608acc`.

## Device evidence

Adapter 24 was staged, archive-hash verified, extracted, component-hash
verified and switched file by file with rollback before the final readback.

- manifest: `adapter_version=24`, `source_ref=8608acc`;
- mutable `installed.json` SHA-256 before and after:
  `4c815e4c4fb1cbd4ee69f7957a2e29f1356832fac1583e6dc091e358bf70e8b6`;
- GUI remained alive beyond 22 seconds;
- process mappings contained only
  `/storage/plumos/emulator/lib/libmali.so.1` and
  `/storage/plumos/emulator/lib/libgbm.so.1` for the GPU path;
- no Mesa DRI, `swrast`, `zink`, utility-app GBM or `EGL not initialized`
  appeared in the final launch range;
- the frontend was absent while the GUI owned DRM; and
- all temporary incoming deployment directories were removed after readback.

Physical menu input and normal GUI exit/FE return are the final live acceptance
step. No PortMaster port scripts are currently installed on the device
(`port_scripts=0`), so a representative downloaded port and per-port static
audit cannot be truthfully accepted in this run.

## Capacity note

Five exact PortMaster rollback directories occupy about 343 MiB. They were
retained because deleting rollback data was not part of this validation. Once
adapter 24 is physically accepted, old intermediate rollback directories can
be removed with an explicit target boundary while retaining the latest known
good rollback.
