# Bubble NDS startup-race remediation (2026-09-05)

## Reported failure and cause

The frontend resolved the real NDS content and the `standalone:drastic`
profile correctly, but the launcher returned status 256. The route log stopped
at `S62_RUNTIME` with `reason=runner-not-ready`.

The Bubble AArch64 runner creates `/dev/shm/NDS_SHM` only after acquiring DRM
and initializing GLES. The old launcher waited at most 20 times 50 ms, while
the runner itself stopped if it had no producer frame after a fixed 1.5 s.
This made a real launch fail whenever Bubble initialization took more than one
second. A previous bounded pass was therefore timing-dependent rather than a
stable acceptance result.

## Correction

- The launcher now waits up to 5 s for the shared-memory readiness marker and
  records both ready and not-ready elapsed time.
- The runner now waits up to 10 s for its first ARMHF producer frame instead of
  stopping after a fixed 1.5 s.
- Bubble no longer executes the inherited `kill -9 $(pidof drastic)` fallback.
  The launcher continues to own and terminate its exact child process.
- Runner logging uses `DEBUG`, so readiness, GLES, shared-memory and content
  initialization remain distinguishable in a later failure.

The startup-race source-built AArch64 runner had SHA-256
`395f8eaaa585f548cff3cedaff9bfe06931297df9883eb3642078262e740aed3`.
The previously validated ARMHF integration libraries and closed DraStic core
were retained unchanged.

## Black scanout follow-up

A subsequent frontend launch proved that process, shared-memory and audio
progress were not sufficient acceptance: the active KMS plane was present but
all 1,228,800 bytes of its 640x480 BGRA buffer were zero. A TRACE run showed
continuous `SHM_CMD_FLUSH` and `SHM_CMD_FLIP`, so the failure was between the
AArch64 runner's GLES calls and KMS presentation.

The packaged `libGLESv2.so.2` and the SDL-selected `libmali.so.1` are separate
files containing the same vendor binary. The dynamic loader therefore created
two Mali library instances. SDL reported a non-null context while the GLES
instance used by the runner reported no current EGL context; shader compilation
failed, and the old runner ignored that failure. The launcher now preloads the
canonical `libmali.so.1` only for the AArch64 runner, so SDL/EGL and direct GLES
symbols resolve through one instance without changing other emulator routes.

The runner now also validates SDL window/context creation, current-context
selection, shader compilation and program linking. It records the Mali vendor,
renderer, GLES version and the first three centre pixels. Fragment alpha is
initialized and restored to 1.0 after the translucent secondary-screen draw;
without this, RGB was present but the scanout alpha channel remained zero.

With both corrections applied temporarily, the real-ROM scanout contained
1,090,978 non-zero bytes and SHA-256
`094382b0e527d753fb8f93c1ac7857f3272d5467e8dbb8998b83d77ba30bee13`.
The captured frame visibly showed the Japanese New Super Mario Bros. game
selection screen at 640x480. The new source-built runner has SHA-256
`8e9f0980b3dde673b98a11ee0ff7ff768a6ec9719cbc3ccb09793905070493a8`.
The test used temporary bind mounts, restored volume from 0 to 3, removed all
test mounts and NDS children, and returned to exactly one frontend process.
Managed deployment and user physical acceptance are recorded separately.

## Real-device result

The device test used the existing user NDS file in place and did not copy,
rename or modify ROM content. Volume was changed from runtime level 3 to 0 only
for the bounded test and restored to 3 afterward.

The corrected launcher reported:

```text
drastic_runner=result=ready wait_ms=1200 pid=21089
drastic_start=armhf-gkd-event2-runner content-Newスーパーマリオブラザーズ Nintendo.nds
```

The ARMHF core then parsed gamecard code `4a443241`, initialized both ARM9 and
ARM7 maps, and remained alive with the AArch64 runner. The runner owned both
`/dev/dri/card0` and `/dev/mali0`. ALSA entered `RUNNING`; `hw_ptr` advanced
from 41,552 to 495,456 over the bounded observation, so this is a real emulation
and audio-progress result rather than process liveness alone.

The harness deliberately forced the route to stop after ten seconds. BusyBox
`timeout` escalated before the launcher's shell trap could finish, leaving the
two exact NDS child processes and seven bind mounts. They were explicitly
terminated/unmounted, the shared-memory marker was removed, governors remained
`ondemand`, volume returned to 3, and exactly one frontend process was restored.
This forced-timeout behavior is not evidence for the normal menu-exit path;
normal Function1 menu, exit and frontend return still need physical acceptance.

The post-launch app-layer verification also exposed that active standalone
configuration had accidentally remained in the global checksum inventory.
DraStic correctly updated its mutable `drastic.cf2`, but that made the old
inventory fail after a valid game launch. `config/standalone/*` is now excluded
alongside active RetroArch configuration; factory standalone defaults remain
managed by the standalone component checksum.

## Deployment integrity

Source `47d8438` was deployed as the launcher, runner, DraStic build manifest,
standalone component manifest/checksum, and app manifest. Staged hashes matched
the host before switching. The device passed all 860 standalone component
checksums. The mutable-config inventory correction was deployed as source
`d5693a5`; active standalone configuration had 13 files and zero were present
in the corrected inventory. The final 12,885-file live app-layer verification
passed after the real NDS launch. Rollback for the NDS runtime change is
retained at:

```text
/storage/plumos/state/update-rollback/973edcf-to-47d8438-nds-20260905T0630Z
```

The inventory-only switch is separately recoverable from:

```text
/storage/plumos/state/update-rollback/47d8438-to-d5693a5-mutable-checksum-20260905T0645Z
```

No release was published. DraStic and the captured vendor Mali runtime remain
non-release-eligible pending their existing license and physical-acceptance
gates.
