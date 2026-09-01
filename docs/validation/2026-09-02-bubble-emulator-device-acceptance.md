# Bubble emulator device acceptance (2026-09-02)

## Scope and media boundary

This pass used the personalized full-stack validation SD and the user's ROM SD.
The ROM SD remained read-only at `/run/media/sd2`; no ROM, BIOS, save, or
frontend setting was copied back to the repository or modified on that media.
The OS-side managed payload was updated only through component manifests and
checksums, with a rollback tar before each live deployment.

The first-boot provisioning did complete even though no setup/progress screen
was visible. Persistent evidence records
`S24A_P3_PARTITION_EXPANDED sectors=16777216`,
`S24D_P4_READY sectors=104148992`, and `S29_SWITCH_ROOT`. The running card has
an 8 GiB p3 and a p4 occupying the remaining card space. Bubble's external
initramfs invokes the common logo but does not yet provide the progress
renderer used by the V90S-family first-boot path. The missing visible progress
is therefore an unresolved UI defect, not evidence that provisioning was
skipped.

## Device evidence

- panel metadata: 640x480, 32 bpp, stride 2560, rotation 0
- DRM: `/dev/dri/card0` with the captured Bubble Mali userspace route for GLES
- input: normalized Bubble controller at `/dev/input/event2`
- audio: RK817 card 0, playback PCM 0
- ROM SD: `/dev/mmcblk3p1`, mounted vfat read-only
- final live app-layer source: `1e44176`
- final top-level checksum verification: 4976/4976 entries passed
- frontend after every test: exactly one process; ALSA playback closed

`ALSA RUNNING` and advancing `hw_ptr`/`appl_ptr` prove that samples reached the
RK817 PCM device. They do not prove audible output from the physical speaker or
headphones. Similarly, driver configuration and a running renderer do not
replace physical confirmation of orientation and aspect ratio.

## Representative content results

| System / route | Content | Process / renderer | PCM evidence | Result |
| --- | --- | --- | --- | --- |
| NES / RetroArch QuickNES | `Super Mario Bros..nes` | ran | RUNNING, pointers advanced | runtime pass; physical picture/speaker still pending |
| NES / PicoArch QuickNES | same | ran with component-scoped SDL2 | RUNNING, pointers advanced | runtime and cleanup pass; physical picture/speaker still pending |
| GBA / RetroArch gpSP | `Mario Kart Advance (Japan).gba` | ran | RUNNING, pointers advanced | runtime pass; physical picture/speaker still pending |
| PS1 / RetroArch PCSX-ReARMed | `SCPS-10026.cue` | ran | RUNNING, pointers advanced | runtime pass; physical picture/speaker still pending |
| N64 / RetroArch ParaLLEl N64 | `Mario Kart 64 [V1.0].z64` | Mali g13p0 initialized and `Gfx RomOpen` completed | PREPARED, `hw_ptr=0` through 40 seconds | fail/open: no audio progression |
| N64 / RetroArch Mupen64Plus-Next | same | process remained alive | PREPARED, `hw_ptr=0` through 20 seconds | fail/open: no audio progression |
| Dreamcast / RetroArch Flycast Xtreme | `Crazy Taxi (Japan).chd` | Mali GLES route ran | RUNNING, pointers advanced | runtime pass; physical picture/speaker still pending |
| Saturn / standalone YabaSanshiro | `VH.iso` with ROM-SD Saturn BIOS | Mali-G52, OpenGL ES 3.2, keep-aspect route | RUNNING, pointers advanced | runtime and normal-exit pass; physical picture/speaker still pending |

No PSP or NDS content was found on the mounted ROM SD, so those content routes
remain untested. DraStic remains visible unsupported as documented in the
catalog rather than being hidden.

## PicoArch correction and lifecycle

The initial PicoArch launch aborted because sdl12-compat could not load SDL2.
Commit `bb79768` adds a pinned, minimal, component-scoped SDL2 build and its
license; its ELF dependencies are limited to `libc.so.6` and `libm.so.6`.
QuickNES then ran without mapping any standalone-emulator library directory.

PicoArch itself ignores TERM on this device. Commits `5482360` and `1e44176`
make the launcher forward the stop request, apply a bounded KILL fallback, and
perform a second wait so BusyBox cannot leave a short-lived child behind. The
device stop test ended with launcher rc 143, no PicoArch process, one frontend
process, and a closed ALSA PCM.

## Display acceptance boundary

The software routes use aspect-fit configuration and no rotation; standalone
YabaSanshiro is invoked with keep-aspect. A `/dev/fb0` readback captured only
the stale plumOS logo because active games scan out through DRM page-flip
buffers. That readback is intentionally not counted as visual acceptance.
Correct orientation, non-stretched aspect ratio, and audible sound must be
confirmed on the physical LCD/speaker for each representative renderer class:
software RetroArch, GLES RetroArch, PicoArch, and GLES standalone.

The currently retained SD image predates the live commits above. It remains a
validation image and must be rebuilt before the next write or release-candidate
gate; the live device is the newer validated state.
