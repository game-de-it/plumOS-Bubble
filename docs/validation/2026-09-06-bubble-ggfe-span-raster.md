# Bubble GGFE span-raster device validation (2026-09-06)

## Scope

Commit `7b208dd` replaces triangle bounding-box walks with scanline spans and
steps perspective terms across each span.  This validation measured the new
rasteriser on the physical Bubble during continuous carousel motion and the
launch animation, then exercised the normal RetroArch return path.

The checked-in output initially carried the previous `ad12c38` source ref.
It was rebuilt from `7b208dd` before deployment.  The resulting AArch64
`bin/plumos-ggfe` was 68,496 bytes with SHA-256
`4ce5f333ed22d0d3c120af0207a825d1b187e43402a715d85a99441115446071`.

## Deployment and display ownership

The complete 212-entry frontend component was staged under
`/storage/plumos/.incoming/7b208dd-ggfe-span/`.  Its transfer archive and
component checksums passed before the atomic switch.  The component manifest,
component checksum file, and the corresponding 213 app-layer checksum entries
were updated together.  Frontend settings, system settings, and core overrides
retained their pre-deployment hashes.

Rollback is available at:

```text
/storage/plumos/state/app-deploy/7b208dd-ggfe-span/rollback.tar
SHA-256 2e768dbc094cb8c0625a39b72644fa0cd9798b51ec660ef817573f64bcf45f83
```

`/run/plumos/validation/frontend-hold` was created before the existing frontend
was terminated once.  The replacement `plumos-frontend-launch` entered the
hold, and `plumos-ggfe` was then started directly as the only renderer.  This
avoided simultaneous FE/GGFE drawing and did not consume repeated early-init
retries.

## Performance result

The device used the expected DRM path:

```text
ggfe_renderer=ready backend=drm xres=640 yres=480 bpp=32 shadow=0 double_buffer=1
```

During sustained D-pad scrolling the measured ranges were:

- frame rate: approximately 11.0 to 14.3 fps
- compose average: approximately 57 to 71 ms, commonly 63 to 68 ms
- blit average: approximately 2.2 ms
- present average: approximately 6 to 10 ms

A representative scrolling interval was:

```text
ggfe_frames=fps=12.00 frames=12 elapsed_ms=1000 max_frame_ms=133 slow_frames=12 compose_us=65560/84302 blit_us=2307/3055 present_us=6986/14854
```

The later launch-animation interval reached about 21 fps with a 38.5 ms
compose average:

```text
ggfe_frames=fps=21.00 frames=21 elapsed_ms=1000 max_frame_ms=67 slow_frames=21 compose_us=38525/62991 blit_us=2372/3893 present_us=6710/15639
```

The span rasteriser is therefore a measurable but insufficient physical-device
improvement over the earlier roughly 9.8 to 13.3 fps result.  The panel
conversion and DRM page flip remain small; `compose_us` is still 3.5 to 4.3
times the 16.6 ms 60 fps budget during scrolling.  The next optimisation must
reduce compose work, with `-DGGFE_PROFILE` available to split clear, opaque
cart, translucent glass, console, and HUD time on the device.

## Launch, return, and teardown

Physical A generated code 305 and launched `Super Monaco GP.gg` through
`retroarch:genesis_plus_gx`.  RetroArch returned successfully:

```text
ggfe_launch=done status=0
```

GGFE reacquired DRM (no `ggfe_renderer=reacquire-failed` was recorded), but the
first test showed that the RetroArch SELECT+START exit chord remained queued on
the evdev fd that GGFE had kept open during the child process.  Immediately
after `ggfe_launch=done`, two `ggfe_input=exit code=315 physical=START` records
caused an unintended GGFE exit.

Commit `e7b08d9` closes GGFE's input fd before handing control to the emulator
and opens a fresh fd after return.  The complete 212-entry frontend component
was rebuilt and deployed with matching component/app-layer metadata.  Its
device binary SHA-256 was
`675bcd6873c0bd15da315cb656281f0c4a07c593182b21c870cae8b7c1dd5ead`.
The physical retest launched `Pengo.gg`, exited RetroArch with SELECT+START,
and recorded:

```text
ggfe_launch=done status=0
ggfe_input=reopened-after-launch
ggfe_scroll=start from=3 to=4 duration_ms=360
```

No `ggfe_input=exit` followed the RetroArch exit chord.  Physical D-pad input
continued to move the carousel, proving that GGFE retained control after the
game.  Physical B then produced code 304 and `ggfe_exit=ok`, returning through
the normal Apps route to the frontend.

The validation hold was removed and the normal frontend returned after three
seconds.  Final state was exactly one
`plumos-controller-ui-fbdev`, no GGFE or RetroArch process, no validation hold,
valid frontend component checksums, and unchanged mutable configuration.

The physical appearance of the improved motion has not been accepted and the
60 fps gate remains open.  Post-game input isolation is accepted.

## Four-core stripe follow-up

Commit `bcaa959` adds a four-core worker pool.  Twenty-four horizontal stripes
are claimed dynamically so the centre-heavy cartridge scene does not leave the
top and bottom workers idle.  `GGFE_PROFILE` was enabled in the device build.
Review found that the commit and documentation claimed lifetime CPU-governor
control, but `plumos-ggfe-launch` still used `exec` and contained no snapshot,
apply, or restore operation.  Commit `bc27cd4` adds the missing
`ondemand -> performance -> ondemand` contract and tests non-zero child exit,
apply failure, and TERM cleanup.

The complete 212-entry frontend component was rebuilt from `bc27cd4`.  Device
hashes after deployment were:

```text
f2ec0a9f13815f7cf2f4e75fd90d1fe1ce47c1ec827b0c8daf2d344ee7d378bc  bin/plumos-ggfe
09718b768aed5fd44103fbd29df05f7252a65dabc6c0deb805cc78d1ecc01880  bin/plumos-ggfe-launch
a53c78fa23db63f8d9d8d3876e3af65e652ea361ce508ecb4a8bc85a69e0584d  components/frontend/checksums.sha256
```

The component's 212 checksums and the corresponding 213 global-catalog entries
passed.  Frontend settings, system settings, and core overrides retained their
pre-deployment hashes.  The initial deployment script treated root-level
`VERSION` as a directory and stopped after switching 211 entries.  The original
component had already been captured; `VERSION`, the component checksum, and the
global entries were completed from the verified staging tree, followed by a
full component check.  A corrected rollback archive is retained under
`/storage/plumos/state/app-deploy/bc27cd4-ggfe-mt/`.

The direct validation used the frontend hold, with GGFE as the only renderer.
The expected runtime state was observed:

```text
ggfe_cpu=apply result=ok requested=performance active=performance
ggfe_renderer=ready backend=drm xres=640 yres=480 bpp=32 shadow=0 double_buffer=1
ggfe_stages=clear=528 console=0 label=715 cart3d=6265 glass=4802 console_front=0 hud=1991 flash=0 threads=4
```

The four-core renderer reduces a static compose interval to about 14.3 ms, with
blit near 2.25 ms.  This is just over the complete 16.6 ms frame deadline, so a
blocking page flip commonly pushes the next presentation to the following
vblank and the observed steady rate remains about 30 to 32 fps.  `compose_us`
alone being below 16.6 ms is therefore not a 60 fps pass.

During physical continuous D-pad scrolling, frame rate ranged from about 27 to
43 fps.  The sustained heavy intervals were normally 30 fps, with compose about
19.5 to 22.1 ms, blit about 2.2 ms, and present about 9 to 16 ms.  A
representative interval was:

```text
ggfe_frames=fps=30.00 frames=30 elapsed_ms=1000 max_frame_ms=34 slow_frames=30 compose_us=22026/22181 blit_us=2213/2226 present_us=9085/9234
ggfe_stages=clear=537 console=0 label=1489 cart3d=9624 glass=7015 console_front=0 hud=3357 flash=0 threads=4
```

The physical A path produced code 305 and launched
`gamegear/Eternal Legend (Japan).gg` through
`retroarch:genesis_plus_gx`.  The launch animation also ran at about 30 fps,
with a 19.1 ms compose average.  RetroArch exited with SELECT+START, GGFE logged
status zero, reopened its input fd, and remained controllable:

```text
ggfe_input=launch code=305 physical=A target=1
ggfe_launch=done status=0
ggfe_input=reopened-after-launch
```

Physical B then produced code 304 and exited GGFE.  No frontend or emulator was
drawing at the same time.  The wrapper restored the exact pre-launch policy:

```text
ggfe_input=exit code=304 physical=B
ggfe_exit=ok
ggfe_cpu=restore result=ok active=ondemand
```

Four workers and lifetime `performance` are accepted.  The 60 fps and motion
acceptance gates remain open.  The next optimisation should reduce the
scrolling scene's `cart3d` and `glass` work; together they account for roughly
16.6 ms of the representative 22.0 ms compose interval.

## Recovery-console power-request observation

Removing the validation hold could not restart the frontend because earlier
device work had already consumed all four restart attempts in that boot.  PID
1 entered `E81_FRONTEND_RESTART_LIMIT_RECOVERY_CONSOLE`, whose current final
action is `exec busybox sh`.  A later `plumos-safe-shutdown --reboot` correctly
quiesced the foreground, SD2, p4, network services, and recorded a PID 1
request, but no supervisor remained to consume it.  The device continued to
answer ICMP with ports 21, 22, and 445 closed until a physical power cycle.
This is a recovery-console lifecycle defect, not a GGFE or governor failure.

The following cold boot accepted the clean-shutdown markers, performed no
automatic filesystem repair, and retained `source_ref=bc27cd4`.  At 4.68
seconds the normal frontend start was dispatched.  The running state had one
frontend renderer, no GGFE/RetroArch process, `ondemand`, no validation hold,
valid 212-entry frontend checksums, unchanged mutable settings, and listening
FTP, SSH, and Samba services.
